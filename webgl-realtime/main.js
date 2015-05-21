var camera, scene, renderer;
var mesh, controls, stats;

var gridSegments = 256

var uniforms = {
    xCenter:{ type: "f", value: .37},
    yCenter:{ type: "f", value: -.34},
    zoom:{ type: "f", value: 1},
    colorAdd:{ type: "f", value: 16},
    colorMult:{ type: "f", value: 19.7/255},
    dispExp:{ type: "f", value: .5},
    dispAdd:{ type: "f", value: 0},
    dispMult:{ type: "f", value: .25},
    compR:{ type: "f", value: 0},
    compI:{ type: "f", value: 0}
}

var time = 0;
var animCenterX = -.433;
var animCenterY = .62;
var animRadX = .025;
var animRadY =  .03;
var speed = .006;

init();
animate();

function createPlane(){
  var geometry = new THREE.PlaneGeometry( 1, 1, gridSegments, gridSegments );

  var material = new THREE.ShaderMaterial( {
    uniforms: uniforms,
    vertexShader: document.getElementById( 'vertexShader' ).textContent,
    fragmentShader: document.getElementById( 'fragmentShader' ).textContent
  } );

  var plane = new THREE.Mesh( geometry, material );
  scene.add( plane );
}

function init() {

  camera = new THREE.PerspectiveCamera( 30, window.innerWidth / window.innerHeight, .01, 1000 );
  camera.position.y = -1.35
  camera.position.z = 1.55
  camera.up.set( 0, 0, 1 )

  controls = new THREE.OrbitControls( camera );
	controls.damping = 0.2;
	controls.addEventListener( 'change', render );

  scene = new THREE.Scene();

  createPlane()

  container = document.getElementById( 'container' );

  renderer = new THREE.WebGLRenderer();
  renderer.setPixelRatio( window.devicePixelRatio );
  renderer.setSize( window.innerWidth, window.innerHeight );
  container.appendChild( renderer.domElement );

  stats = new Stats();
  stats.domElement.style.position = 'absolute';
  stats.domElement.style.top = '0px';
  stats.domElement.style.zIndex = 100;
  container.appendChild( stats.domElement );

  window.addEventListener( 'resize', onWindowResize, false );

}

function onWindowResize() {

  camera.aspect = window.innerWidth / window.innerHeight;
  camera.updateProjectionMatrix();

  renderer.setSize( window.innerWidth, window.innerHeight );

}

function animate() {

  requestAnimationFrame( animate );
  controls.update();
  render();

}

function render(){
  time += speed;
  uniforms.compR.value = animCenterX + animRadX * Math.cos(time);
  uniforms.compI.value = animCenterY + animRadY * Math.sin(time);
  renderer.render( scene, camera );
  stats.update();
}
