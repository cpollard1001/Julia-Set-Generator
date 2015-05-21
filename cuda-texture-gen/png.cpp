#include <stdio.h>
#include <math.h>
#include <malloc.h>
#include <png.h>

typedef enum {LINEAR, LOG, EXP} mapping;
typedef enum {RED,BLUE, BW, INV} colorScheme;

typedef struct {
  mapping map;
  colorScheme cs;
  double exp;
  double add;
  double mult;
} renderSetting;

inline void setRGB(png_byte *ptr, double val, renderSetting* setting)
{

  double intensity;
  //takes val, maps it to between 0 and 1
  if(setting->map == LINEAR){
    intensity = (val + setting->add)*(setting->mult);
  }else if(setting->map == LOG){
    intensity = (log(val) +setting->add)*(setting->mult);
  }else if(setting->map == EXP){
    intensity = (pow(val,setting->exp) + setting->add)*(setting->mult);
  }

  //takes intensity, turns it into rgb components
  int r; int g; int b;
  if(setting->cs == RED){
    r = intensity * 65536 * 2;
    g = intensity * 65536 * 2 - 65536;
    b = 0;
  }
  if(setting->cs == BLUE){
    r = 0;
    g = intensity * 65536 * 2 - 65536;
    b = intensity * 65536 * 2;
  }
  if(setting->cs == BW){
    r = intensity * 65536;
    g = intensity * 65536;
    b = intensity * 65536;
  }
  if(setting->cs == INV){
    r = 65536 - (intensity * 65536);
    g = 65536 - (intensity * 65536);
    b = 65536 - (intensity * 65536);
  }
  //clip r, g, and b to range
  if(r>65535) r = 65535;
  if(r<0) r = 0;
  if(g>65535) g = 65535;
  if(g<0) g = 0;
  if(b>65535) b = 65535;
  if(b<0) b = 0;

  if(setting->cs == BW || setting->cs == INV){
    ptr[0] = r/256; ptr[1] = r%256;
  }else{
    ptr[0] = r/256; ptr[1] = r%256;
    ptr[2] = g/256; ptr[3] = g%256;
    ptr[4] = b/256; ptr[5] = b%256;
  }
}

int writeImage(char* filename, int width, int height, double *buffer, renderSetting* setting)
{
	int code = 0;
	FILE *fp;
	png_structp png_ptr;
	png_infop info_ptr;
	png_bytep row;
	fp = fopen(filename, "wb");
	if (fp == NULL) {
		fprintf(stderr, "Could not open file %s for writing\n", filename);
		code = 1;
		goto finalise;
	}
	png_ptr = png_create_write_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
	if (png_ptr == NULL) {
		fprintf(stderr, "Could not allocate write struct\n");
		code = 1;
		goto finalise;
	}
	info_ptr = png_create_info_struct(png_ptr);
	if (info_ptr == NULL) {
		fprintf(stderr, "Could not allocate info struct\n");
		code = 1;
		goto finalise;
	}
	if (setjmp(png_jmpbuf(png_ptr))) {
		fprintf(stderr, "Error during png creation\n");
		code = 1;
		goto finalise;
	}
	png_init_io(png_ptr, fp);
  if(setting->cs == BW || setting->cs == INV){
    png_set_IHDR(png_ptr, info_ptr, width, height,
        16, PNG_COLOR_TYPE_GRAY, PNG_INTERLACE_NONE,
        PNG_COMPRESSION_TYPE_BASE, PNG_FILTER_TYPE_BASE);
    png_write_info(png_ptr, info_ptr);
    row = (png_bytep) malloc(2 * width * sizeof(png_byte));
    int x, y;
    for (y=0 ; y<height ; y++) {
      for (x=0 ; x<width ; x++) {
        setRGB(&(row[x*2]), buffer[y*width + x], setting);
      }
      png_write_row(png_ptr, row);
    }
  }else{
    png_set_IHDR(png_ptr, info_ptr, width, height,
        16, PNG_COLOR_TYPE_RGB, PNG_INTERLACE_NONE,
        PNG_COMPRESSION_TYPE_BASE, PNG_FILTER_TYPE_BASE);
    png_write_info(png_ptr, info_ptr);
    row = (png_bytep) malloc(6 * width * sizeof(png_byte));
    int x, y;
    for (y=0 ; y<height ; y++) {
      for (x=0 ; x<width ; x++) {
        setRGB(&(row[x*6]), buffer[y*width + x], setting);
      }
      png_write_row(png_ptr, row);
    }
  }
	png_write_end(png_ptr, NULL);
	finalise:
	if (fp != NULL) fclose(fp);
	if (info_ptr != NULL) png_free_data(png_ptr, info_ptr, PNG_FREE_ALL, -1);
	if (png_ptr != NULL) png_destroy_write_struct(&png_ptr, (png_infopp)NULL);
	if (row != NULL) free(row);

	return code;
}
