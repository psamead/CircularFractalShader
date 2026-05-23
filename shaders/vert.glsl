//-------------------------------------------
varying vec4 vClipPosition;
//-------------------------------------------

void main() 
{
    // gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
    
    //-------------------------------------------
    // Standard Three.js transformation
    vec4 mvPosition = modelViewMatrix * vec4(position, 1.0);
    vClipPosition = projectionMatrix * mvPosition;
    
    gl_Position = vClipPosition;
    //-------------------------------------------
}