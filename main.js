// import * as THREE from 'https://cdn.skypack.dev/three@0.136';
import * as THREE from './libs/three.module.js';

// import {GLTFLoader} from 'https://cdn.skypack.dev/three@0.136/examples/jsm/loaders/GLTFLoader.js';
// import {OrbitControls} from 'https://cdn.skypack.dev/three@0.136/examples/jsm/controls/OrbitControls.js';

// import {GLTFLoader} from './libs/GLTFLoader.js';
// import {OrbitControls} from './libs/OrbitControls.js';


class CircularFractalGLSL {
  constructor() {
  }


  async initialize() {
    this.threejs_ = new THREE.WebGLRenderer();
    this.threejs_.outputEncoding = THREE.sRGBEncoding;
    document.body.appendChild(this.threejs_.domElement);

    window.addEventListener('resize', () => {
      this.onWindowResize_();
    }, false);

    this.scene_ = new THREE.Scene();

    this.camera_ = new THREE.OrthographicCamera(0, 1, 1, 0, 0.1, 1000);
    this.camera_.position.set(0, 0, 1);

    /*
    this.camera_ = new THREE.PerspectiveCamera(60, 1920.0/1080.0, 0.1, 1000.0);
    this.camera_.position.set(1, 0, 3);
    */

    /*
    const controls = new OrbitControls(this.camera_, this.threejs_.domElement);
    controls.target.set(0, 0, 0);
    controls.update();
    */

    /*
    const loader = new THREE.CubeTextureLoader();
    const texture = loader.load([
      './resources/Cold_Sunset__Cam_2_Left+X.png',
      './resources/Cold_Sunset__Cam_3_Right-X.png',
      './resources/Cold_Sunset__Cam_4_Up+Y.png',
      './resources/Cold_Sunset__Cam_5_Down-Y.png',
      './resources/Cold_Sunset__Cam_0_Front+Z.png',
      './resources/Cold_Sunset__Cam_1_Back-Z.png',
    ]);
    */

    // texture.magFilter = THREE.LinearFilter;
    // this.scene_.background = texture;

    await this.setupProject_();

    this.previousRAF_ = null;
    this.onWindowResize_();
    this.raf_();
  }


  


  async setupProject_() {
    // const vsh = await fetch('./shaders/vertex-shader.glsl');
    // const fsh = await fetch('./shaders/fragment-shader.glsl');
    const vsh = await fetch('./shaders/vert.glsl');
    const fsh = await fetch('./shaders/frag.glsl');

    const material = new THREE.ShaderMaterial({
      // setting uniforms for shader
      uniforms: {
        // specMap:{ value: this.scene_.background },
        time:{ value: 0.0, },
        resolution:{value: new THREE.Vector2(window.innerWidth,window.innerHeight)},
      },
      vertexShader: await vsh.text(),
      fragmentShader: await fsh.text()
    });

/*
    const loader = new GLTFLoader();
    loader.setPath('./resources/');
    loader.load('suzanne.glb', (gltf) => {
      gltf.scene.traverse(c => {
        c.material = material;
      });
      this.scene_.add(gltf.scene);
    });
*/

    this.material_ = material;
    
    const geometry = new THREE.PlaneGeometry(1, 1);
    const plane = new THREE.Mesh(geometry, material);
    plane.position.set(0.5, 0.5, 0);
    this.scene_.add(plane);

/*
    const geometry = new THREE.IcosahedronGeometry(1, 128);
    const mesh = new THREE.Mesh(geometry, material);
    this.scene_.add(mesh);
*/

/*
    const geometry = new THREE.BoxGeometry(1, 1);
    const mesh = new THREE.Mesh(geometry, material);
    this.scene_.add(mesh);
*/

    this.totalTime_ = 0.0;
    this.onWindowResize_();
  }

  onWindowResize_() {
    /*
    this.threejs_.setSize(window.innerWidth, window.innerHeight);

    this.camera_.aspect = window.innerWidth / window.innerHeight;
    this.camera_.updateProjectionMatrix();
    */

    const dpr = window.devicePixelRatio;
    const canvas = this.threejs_.domElement;
    canvas.style.width = window.innerWidth + 'px';
    canvas.style.height = window.innerHeight + 'px';
    const w = canvas.clientWidth;
    const h = canvas.clientHeight;

    this.threejs_.setSize(w * dpr, h * dpr, false);
    this.material_.uniforms.resolution.value = new THREE.Vector2(
      window.innerWidth*dpr, window.innerHeight*dpr);
  }

  raf_() {
    requestAnimationFrame((t) => {
      if(this.previousRAF_ === null)
      {
        this.previousRAF_ = t;
      }

      this.step_(t-this.previousRAF_);
      this.threejs_.render(this.scene_, this.camera_);
      this.raf_();
      this.previousRAF_ = t;
    });
  }


  step_(timeElapsed)
  {
    const timeElapsedS = timeElapsed * 0.001;
    this.totalTime_ += timeElapsedS;

    this.material_.uniforms.time.value = this.totalTime_;
  } 

}


let APP_ = null;

window.addEventListener('DOMContentLoaded', async () => {
  APP_ = new CircularFractalGLSL();
  await APP_.initialize();
});

