#include "png.cpp"
#include <complex>
#include <string.h>
#include <limits>
#include <cstdlib>
#include <iostream>
void __cudaCheck(cudaError err, const char* file, const int line);
#define cudaCheck(err) __cudaCheck (err, __FILE__, __LINE__)
void __cudaCheckLastError(const char* errorMessage, const char* file, const int line);
#define cudaCheckLastError(msg) __cudaCheckLastError (msg, __FILE__, __LINE__)

void __cudaCheck(cudaError err, const char *file, const int line)
{
  if( cudaSuccess != err) {
    fprintf(stderr, "%s(%i) : CUDA Runtime API error %d: %s.\n",
      file, line, (int)err, cudaGetErrorString( err ) );
    exit(-1);
  }
}
void __cudaCheckLastError(const char *errorMessage, const char *file, const int line)
{
  cudaError_t err = cudaGetLastError();
  if( cudaSuccess != err) {
    fprintf(stderr, "%s(%i) : getLastCudaError() CUDA error : %s : (%d) %s.\n",
      file, line, errorMessage, (int)err, cudaGetErrorString( err ) );
    exit(-1);
  }
}

using namespace std;

double sample(double x, double y, complex<double> comp) {
  double mag = 0;
  int count = 0;
  complex<double> dz(1, 0);
  complex<double> point(x,y);
  complex<double> two(2,0);
  while (count < 1024 && mag < 1e20) {
    dz = two*dz*point;
    point = point*point + comp;
    mag = abs(point);
    count++;
  }
  double dist = log(mag) * mag / abs(dz);
  return dist;
}

void juliaSet(double buffer[], int width, int height,double xCenter, double yCenter,double gridWidth,int samplesPerPixel,complex<double> comp){
  for(int i = 0; i < width; i++){
    for(int j = 0; j < height; j++){
      double intensity = 0;
      for(int k = 0; k < samplesPerPixel; k++){
        double randNum = ((double)rand()/(double)RAND_MAX);
        double x = xCenter + gridWidth * (i - width / 2) / width + randNum / width;
        randNum = ((double)rand()/(double)RAND_MAX);
        double y = yCenter + gridWidth * height / width * (j - height / 2) / height + randNum / height;
        intensity += sample(x,y,comp);
      }
      intensity = intensity / samplesPerPixel;
      buffer[i*width+j] = intensity;
    }
    if(i%50==0) printf("%d\n",i);
  }
}

void getFileName(char* fileName,char* folder,int frame,char* subFolder){
  char temp[20];
  strcpy(fileName,folder);
  strcat(fileName,"/");
  strcat(fileName,subFolder);
  strcat(fileName,"/");
  sprintf(temp, "%05d", frame);
  strcat(fileName,temp);
  strcat(fileName,".png");
}

void writeImages(double* buffer,int width,int height,int frame,char* folder){
  renderSetting setting;
  char fileName[30];

  char subFolder[20] = "Red";
  getFileName(fileName, folder, frame, subFolder);

  printf(fileName);

  /*setting.map = LOG;
  setting.cs = RED;
  setting.add = 15;//16;
  setting.mult = 17.0/255;//19.7/255;
  writeImage(fileName, width, height, buffer, &setting);*/

  strcpy(subFolder,"Blue");
  getFileName(fileName, folder, frame, subFolder);
  setting.map = LOG;
  setting.cs = BLUE;
  setting.add = 15;//16;
  setting.mult = 17.0/255;//19.7/255;
  writeImage(fileName, width, height, buffer, &setting);

  strcpy(subFolder,"Bump");
  getFileName(fileName, folder, frame, subFolder);
  setting.map = LOG;
  setting.cs = BW;
  setting.add = 15;//16;
  setting.mult = 17.0/255;//19.7/255;
  writeImage(fileName, width, height, buffer, &setting);

  strcpy(subFolder,"Disp");
  getFileName(fileName, folder, frame, subFolder);
  setting.cs = INV;
  setting.map = EXP;
  setting.exp = .9;
  setting.add = 0;
  setting.mult = 6000.0/255;
  writeImage(fileName, width, height, buffer, &setting);
}

__device__ double cudasample(double x, double y, double compR, double compI) {
  double mag = 0;
  int count = 0;
  double dzR = 1;
  double dzI = 0;
  double pointR = x;
  double pointI = y;
  while (count < 1024 && mag < 1e5) {
    double tmpdzR = 2 * (dzR * pointR - dzI * pointI);
    dzI = 2 * (dzR*pointI + dzI*pointR);
    dzR = tmpdzR;

    double tmpPointR = pointR*pointR - pointI*pointI + compR;
    pointI = 2 * pointR *pointI + compI;
    pointR = tmpPointR;

    mag = sqrt(pointR*pointR + pointI*pointI);
    count++;
  }
  double dist = logf(mag) / sqrt(dzR*dzR+dzI*dzI) * mag;
  return dist;
}

__global__ void cudaJulia(double buffer[], int width, int height,double xCenter, double yCenter,double gridWidth,int samplesPerPixel,double compR, double compI,int rep) {
  int index = threadIdx.x + blockIdx.x * blockDim.x + rep*4096*blockDim.x;
  if(index < width * height){
    int i = index % width;
    int j = index / height;
    double intensity = 0;
    for(int k = 0; k < samplesPerPixel; k++){
      double random = ((double)k)/samplesPerPixel/width;
      double x = xCenter + gridWidth * (i - width / 2) / width + random / width;
      random = ((index+k)%samplesPerPixel)/samplesPerPixel/height;
      double y = yCenter + gridWidth * height / width * (j - height / 2) / height + random / height;
      intensity += cudasample(x,y,compR, compI);
    }
    intensity = intensity / samplesPerPixel;
    buffer[index] = intensity;
  }
}

int main(int argc, char *argv[])
{
	int width = 1024;
	int height = 1024;
  double xCenter = 0;//.377;
  double yCenter = 0;//-.343;
  double gridWidth = 1.0;
  double samplesPerPixel = 1;
  char folder[20] = "Test";

  int t = 0;
  double animCenterX = -.77;//-.433;
  double animCenterY = .156;//.62;
  double animRadX = .025;
  double animRadY = .01;//.03;
  double speed = .006;

  int blocksize = 1024;
  int gridsize = width*height/blocksize;
  int numReps = 1;
  if(gridsize > 4096){
    numReps = gridsize/4096;
    gridsize = 4096;
  }

  int numFrames = 2 * 3.1415926535 / speed;
  printf("%d frames total\n",numFrames);


  int bufferSize = width * height * sizeof(double);
  double* buffer = (double *) malloc(bufferSize);
  double* bufferd;
  cudaCheck(cudaMalloc( (void**)&bufferd, bufferSize ));

  dim3 dimBlock( blocksize, 1 );
  dim3 dimGrid( gridsize, 1 );

  while(t < numFrames){
    double xJParam = animCenterX + animRadX * cos(t*speed);
    double yJParam = animCenterY + animRadY * sin(t*speed);
    complex<double> comp(xJParam,yJParam);

    printf("Frame %d, r = %f, i = %f\n",t,xJParam,yJParam);
    //call cudaJulia, pass all the same arguments
    int rep = 0;
    while(rep<numReps){
      cudaJulia<<<dimGrid, dimBlock>>>(bufferd, width, height, xCenter, yCenter, gridWidth, samplesPerPixel, comp.real(), comp.imag(),rep);
      cudaCheckLastError("Failure");
      rep++;
    }
    //copy memory back to cpu
    cudaMemcpy( buffer, bufferd, bufferSize, cudaMemcpyDeviceToHost );
    //juliaSet(buffer, width, height, xCenter, yCenter, gridWidth, samplesPerPixel, comp);
    //sort / analyze histogram if needed, hopefully not though
    //write images
    writeImages(buffer,width,height,t,folder);

    t = t + 1;
  }

  cudaFree( bufferd );
	free(buffer);

	return 0;
}
