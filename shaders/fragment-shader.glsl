
// uniform samplerCube specMap;
uniform vec2 resolution;
uniform float time;

varying vec3 vNormal;
varying vec3 vPosition;
varying vec3 vColor;
varying vec2 vUvs;

vec3 YELLOW = vec3(1.0, 1.0, 0.5);
vec3 BLUE = vec3(0.25, 0.25, 1.0);
vec3 RED = vec3(1.0, 0.25, 0.25);
vec3 GREEN = vec3(0.25, 1.0, 0.25);
vec3 PURPLE = vec3(1.0, 0.25, 1.0);


float InverseLerp(float currentValue, float minValue, float maxValue)
{
  return (currentValue - minValue) / (maxValue - minValue);
}

float Remap(float currentValue, float inMin, float inMax, float outMin, float outMax)
{
  float t = InverseLerp(currentValue, inMin, inMax);
  return mix(outMin, outMax, t);
}

vec3 linearTosRGB(vec3 value) // glsl version
{
  vec3 lt = vec3(lessThanEqual(value.rgb, vec3(0.0031308)));

  vec3 v1 = value * 12.92;
  vec3 v2 = pow(value.xyz, vec3(0.41666))*1.055 - vec3(0.055);

  return mix(v2, v1, lt);
}

/*
// the concept of linear to sRGB function, which is done in two steps: 1. linear -> Gamma; 2. Gamma -> sRGB.
vec3 linearToSRGB_CVersion(vec3 value) // c version linear to sRGB: 2.Gamma -> sRGB
{
  return vec3(toSRGB(value.x), toSRGB(value.y), toSRGB(value.z));
}

float toSRGB(float value)  // c version linear to sRGB: 1.linear -> Gamma
{
  if(value < 0.0031308) { return value *  12.92; }
  
  return  pow(value, 0.41666) * 1.055 - 0.055;
}
*/


// Phong Implementation
vec3 phongSpecular(vec3 viewDir, vec3 lightDir, vec3 lightColor, vec3 normal)
{
  vec3 reflectDir = normalize(reflect(-lightDir, normal));
  float phongValue = max(0.0, dot(viewDir, reflectDir));
  phongValue = pow(phongValue, 32.0); // the power control the size of specular

  return lightColor * phongValue;
}

// Diffuse Implementation
vec3 diffuseLighting(vec3 lightDir, vec3 lightColor, vec3 normal)
{
  float dp = max(0.0, dot(lightDir, normal));
  return lightColor * dp;
}

// IBL Specular Implementation
vec3 iblSpecular(vec3 viewDir, vec3 normal, samplerCube specMap)
{
  vec3 iblCoord = normalize(reflect(-viewDir, normal));
  vec3 iblSample = textureCube(specMap, iblCoord).xyz;
  return iblSample;
}

// Frensel Effect
float Fresnel(vec3 viewDir, vec3 normal)
{
  float fresnel = 1.0 - max(0.0, dot(viewDir, normal));
  fresnel = pow(fresnel, 2.0);
  return fresnel;
}

vec3 BackgroundColor()
{
  float distFromCenter = length(abs(vUvs - 0.5));

  float vignette = 1.0 - distFromCenter;
  vignette = smoothstep(0.0, 0.7, vignette);
  vignette = Remap(vignette, 0.0, 1.0, 0.3, 1.0);

  return vec3(vignette);
}

vec3 drawGrid(vec3 color, vec3 lineColor, float cellSpacing, float lineWidth)
{
  vec2 center = vUvs - 0.5;
  vec2 cells = abs(fract(center * resolution / cellSpacing) - 0.5);
  float distToEdge = (0.5 - max(cells.x, cells.y)) * cellSpacing;
  float lines = smoothstep(0.0, lineWidth, distToEdge);

  color = mix(lineColor, color, lines);

  return color;
}

float sdfCircle(vec2 p, float r)
{
  return length(p) - r;
}

float sdfLine(vec2 p, vec2 a, vec2 b)
{
  vec2 pa = p - a;
  vec2 ba = b - a;
  float h = clamp(dot(pa, ba)/dot(ba, ba), 0.0, 1.0);

  return length(pa - ba*h);
}

float sdfBox(vec2 p, vec2 b)
{
  vec2 d = abs(p) - b;
  return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);

}

// Inigo Quillez
// https://iquilezles.org/articles/distfunctions2d/
float sdfHexagon( in vec2 p, in float r )
{
    const vec3 k = vec3(-0.866025404,0.5,0.577350269);
    p = abs(p);
    p -= 2.0*min(dot(k.xy,p),0.0)*k.xy;
    p -= vec2(clamp(p.x, -k.z*r, k.z*r), r);
    return length(p)*sign(p.y);
}

// Inigo Quillez
// Heart - exact   (https://www.shadertoy.com/view/3tyBzV)
float dot2( in vec2 v ) { return dot(v,v); }
float sdfHeart( in vec2 p )
{
    p.x = abs(p.x);

    if( p.y+p.x>1.0 )
        return sqrt(dot2(p-vec2(0.25,0.75))) - sqrt(2.0)/4.0;
    return sqrt(min(dot2(p-vec2(0.00,1.00)),
                    dot2(p-0.5*max(p.x+p.y,0.0)))) * sign(p.x-p.y);
}
float sdfHeart( in vec2 p, in float r, in vec2 offset)
{
    p /= r;
    p -= offset;
    p.x = abs(p.x);
    // p.x = abs(p.x)*(1.0/r);
    // p.y = p.y*(1.0/r);
    // p.y += 0.5;

    if( p.y+p.x>1.0 )
        return sqrt(dot2(p-vec2(0.25,0.75))) - sqrt(2.0)/4.0;
    return sqrt(min(dot2(p-vec2(0.00,1.00)),
                    dot2(p-0.5*max(p.x+p.y,0.0)))) * sign(p.x-p.y);
}

// Inigo Quillez
// Cross - exact exterior, bound interior   (https://www.shadertoy.com/view/XtGfzw)
/*
// orignal
float sdCross( in vec2 p, in vec2 b, float r ) 
{
    p = abs(p); p = (p.y>p.x) ? p.yx : p.xy;
    vec2  q = p - b;
    float k = max(q.y,q.x);
    vec2  w = (k>0.0) ? q : vec2(b.y-p.x,-k);
    return sign(k)*length(max(w,0.0)) + r;
}
*/
float sdfCross( in vec2 p, in vec2 b, float r ) 
{
    p = abs(p)/r; 
    p = (p.y>p.x) ? p.yx : p.xy;
    vec2  q = p - b;
    float k = max(q.y,q.x);
    vec2  w = (k>0.0) ? q : vec2(b.y-p.x,-k);
    return sign(k)*length(max(w,0.0)) * r;
}

mat2 rotate2D(float angle)
{
  float s = sin(angle);
  float c = cos(angle);
  return mat2
            (c, -s,
             s,  c );
}

float opUnion(float d1, float d2)
{
  return min(d1, d2);
}

float opSubtraction(float d1, float d2)
{
  return max(-d1, d2);
}

float opIntersection(float d1, float d2)
{
  return max(d1, d2);
}

float softMax(float a, float b, float k)
{
  return log(exp(k*a) + exp(k*b)) / k;
}

float softMin(float a, float b, float k)
{
  return -softMax(-a, -b, k);
}

float softMinValue(float a, float b, float k)
{
  // float h = exp(-b*k)/(exp(-a*k)+exp(-b*k));
  float h = Remap(a-b, -1.0/k, 1.0/k, 0.0, 1.0);
  return h;
}
float softMinValue2(float a, float b, float k)
{
  float h = exp(-b*k)/(exp(-a*k)+exp(-b*k));
  return h;
}

vec3 DrawBackground(float dayTime)
{
  vec3 morning = mix(vec3(0.44, 0.64, 0.84),
                     vec3(0.34, 0.51, 0.94), 
                       smoothstep(0.0, 1.0, pow(vUvs.x * vUvs.y, 0.5)));

  vec3 midday = mix(vec3(0.42, 0.58, 0.75),
                     vec3(0.36, 0.46, 0.82), 
                       smoothstep(0.0, 1.0, pow(vUvs.x * vUvs.y, 0.5)));

  vec3 evening = mix(vec3(0.82, 0.51, 0.25),
                     vec3(0.88, 0.71, 0.39), 
                       smoothstep(0.0, 1.0, pow(vUvs.x * vUvs.y, 0.5)));
  
  vec3 night = mix(vec3(0.07, 0.1, 0.19),
                     vec3(0.36, 0.46, 0.82), 
                       smoothstep(0.0, 1.0, pow(vUvs.x * vUvs.y, 0.5)));

  float dayLength = 20.0;
  // float dayTime = mod(time, dayLength);

  vec3 color;
  if(dayTime < dayLength * 0.25)
  {
    color = mix(morning, midday, smoothstep(0.0, dayLength*0.25, dayTime ));
  }
  else if(dayTime < dayLength * 0.5)
  {
    color = mix(midday, evening, smoothstep(dayLength*0.25, dayLength*0.5, dayTime ));
  }
  else if(dayTime < dayLength * 0.75)
  {
    color = mix(evening, night, smoothstep(dayLength*0.5, dayLength*0.75, dayTime ));
  } 
  else
  {
    color = mix(night, morning, smoothstep(0.75, dayLength, dayTime ));
  }

  // return mix(vec3(0.42, 0.58, 0.75), 
  //            vec3(0.36, 0.46, 0.82), 
  //            pow(smoothstep(0.0, 1.0, vUvs.x * vUvs.y), 0.5));
  
  // return mix(vec3(0.42, 0.58, 0.75), 
  //            vec3(0.36, 0.46, 0.82), 
  //            smoothstep(0.0, 1.0, POW(vUvs.x * vUvs.y, 0.5)));

  return color;
}

float sdfCloud(vec2 pixelCoords)
{
  float puff1 = sdfCircle(pixelCoords, 100.0);
  float puff2 = sdfCircle(pixelCoords-vec2(120.0, -10.0), 75.0);
  float puff3 = sdfCircle(pixelCoords+vec2(120, 10.0), 75.0);
  // float unionPuffs = opUnion(puff1, opUnion(puff2, puff3));
  // return unionPuffs;
  return min(puff1, min(puff2, puff3));
}

float hash(vec2 v)
{
  float t = dot(v, vec2(36.5323, 73.945));
  return sin(t);
}

float saturate(float t)
{
  return clamp(t, 0.0, 1.0);

}

float easeOut(float x, float p)
{
  return 1.0 - pow(1.0-x, p);
}

float sdfMoon(vec2 pixelCoords)
{
  float d = opSubtraction(sdfCircle(pixelCoords + vec2(50.0, 0.0), 80.0), sdfCircle(pixelCoords, 80.0));
  return d;
}

float easeOutBounce(float x)
{
  const float n1 = 7.5625;
  const float d1 = 2.75;

  if(x < 1.0 / d1)
  {
    return n1 * x * x;
  }
  else if(x < 2.0 / d1)
  {
    x -= 1.5 / d1;
    return n1 * x * x + 0.75;
  }
  else if(x < 2.5 / d1)
  {
    x -= 2.25 / d1;
    return n1 * x * x + 0.9375;
  }
  else
  {
    x -= 2.625 / d1;
    return n1 * x * x + 0.984375;
  }
}

float sdfStar5(in vec2 p, in float r, in float rf)
{
  const vec2 k1 = vec2(0.809016994375, -0.587785252292);
  const vec2 k2 = vec2(-k1.x, k1.y);
  p.x = abs(p.x);
  p -= 2.0*max(dot(k1, p), 0.0)*k1;
  p -= 2.0*max(dot(k2, p), 0.0)*k2;
  p.x = abs(p.x);
  p.y -= r;
  vec2 ba = rf*vec2(-k1.y, k1.x)-vec2(0.0, 1.0);
  float h = clamp(dot(p, ba)/dot(ba, ba), 0.0, r);
  return length(p-ba*h) * sign(p.y*ba.x-p.x*ba.y);
}


void main()
 {
  // vec2 pixelCoords = (vUvs - 0.5) * resolution;
  vec2 pixelCoords = vUvs * resolution;

  float dayLength = 20.0;
  float dayTime = mod(time + 8.0, dayLength);
  
  vec3 color = DrawBackground(dayTime);


  // SUN
  if(dayTime < dayLength * 0.75)
  {
    float t = saturate(InverseLerp(dayTime, 0.0, 1.0)); 

    vec2 offset = vec2(200.0, resolution.y * 0.8) 
                + mix(vec2(0.0, 400.0), vec2(0.0), easeOut(t, 5.0)); // animate sun to drop down from top
    

    if(dayTime > dayLength * 0.5) // animate sun to moving up to top
    {
      float t = saturate(InverseLerp(dayTime, dayLength*0.5, dayLength*0.5 + 1.0));
      offset = vec2(200.0, resolution.y*0.8) + mix(vec2(0.0), vec2(0.0, 400.0), t);

    }

    vec2 sunPos = pixelCoords - offset;

    float sun = sdfCircle(sunPos, 100.0);
    color = mix(vec3(0.84, 0.62, 0.26), color, smoothstep(0.0, 2.0, sun)); // draw sun circle shape on the canvas
  
    float s = max(0.001, sun);  // define an exponential falloff to draw sun glow
    float p = saturate(exp(-0.001*s*s));  // fog equation
    color += 0.5*mix(vec3(0.0), vec3(0.9, 0.85, 0.47), p);
  }


  // MOON
  if(dayTime > dayLength * 0.5)
  {
    float t = saturate(InverseLerp(dayTime, dayLength * 0.5, dayLength * 0.5 + 1.5)); 

    vec2 offset = resolution * 0.8 
                + mix(vec2(0.0, 400.0), vec2(0.0), easeOutBounce(t)); // animate sun to drop down from top
    

    if(dayTime > dayLength * 0.9) // animate sun to moving up to top
    {
      float t = saturate(InverseLerp(dayTime, dayLength*0.9, dayLength*0.95));
      offset = resolution * 0.8 + mix(vec2(0.0), vec2(0.0, 400.0), t);

    }

    vec2 moonShadowPos = pixelCoords - offset + vec2(15.0);
    moonShadowPos = rotate2D(3.14159 * -0.2)*moonShadowPos;

    float moonShadow = sdfMoon(moonShadowPos);
    color = mix(vec3(0.0), color, smoothstep(-40.0, 10.0, moonShadow)); // draw moon shadow shape on the canvas


    vec2 moonPos = pixelCoords - offset;
    moonPos = rotate2D(3.14159 * -0.2)*moonPos;

    float moon = sdfMoon(moonPos);
    color = mix(vec3(1.0), color, smoothstep(0.0, 2.0, moon)); // draw moon shape on the canvas

    float moonGlow = sdfMoon(moonPos);
    color += 0.1 * mix(vec3(1.0), vec3(0.0), smoothstep(-10.0, 15.0, moonGlow)); // draw moon glow shape on the canvas  
  }

  
  // STARS
  const float NUM_STARS = 24.0;
  for(float i = 0.0; i < NUM_STARS; i += 1.0)
  {
    float hashSample = hash(vec2(i * 13.0)) * 0.5 + 0.5;

    float t = saturate(InverseLerp(dayTime+hashSample*0.5, dayLength * 0.5, dayLength * 0.5 + 1.5));

    float fade = 0.0;
    if(dayTime > dayLength * 0.9)
    {
      fade = saturate(InverseLerp(dayTime-hashSample*0.25, dayLength*0.9, dayLength*0.95));
    }

    float size = mix(2.0, 1.0, hash(vec2(i, i+1.0)));
    vec2 offset = vec2(i * 100.0, 0.0) + 150.0 * hash(vec2(i));
    offset += mix(vec2(0.0, 600.0), vec2(0.0), easeOutBounce(t));

    float rot = mix(-3.14159, 3.14159, hashSample);

    vec2 pos = pixelCoords - offset;
    pos.x = mod(pos.x, resolution.x);
    pos = pos - resolution * vec2(0.5, 0.75);
    // pos = rotate2D(rot) * pos;
    pos = rotate2D(rot + time*hash(vec2(i, i+.2))) * pos;
    pos *= size;


    float star = sdfStar5(pos, 10.0, 2.0);

    vec2 starShadowPos = pos + vec2(2.5);
    starShadowPos = rotate2D(3.14159 * -0.05)*starShadowPos;

    float starShadow = sdfStar5(starShadowPos, 11.0, 2.1);
    vec3 starShadowColor = mix(vec3(0.0), color, smoothstep(-40.0, 10.0, starShadow)); // draw star shadow shape on the canvas
    color = mix(starShadowColor, color, fade);


    vec3 starColor = mix(vec3(1.0), color, smoothstep(0.0, 2.0, star));
    starColor += mix(0.2, 0.0, pow(smoothstep(-5.0, 15.0, star), 0.25));

    color = mix(starColor, color, fade);
  }


  // CLOUDS
  const float NUM_CLOUDS = 8.0;
  for(float i = 0.0; i < NUM_CLOUDS; i++)
  {
    float size = mix(2.0, 1.0, (i/NUM_CLOUDS) + 0.1*hash(vec2(i)));
    float speed = size * 0.25;

    vec2 offset = vec2(i*200.0 + time*100.0*speed, 200.0*hash(vec2(i)));
    vec2 pos = pixelCoords - offset;

    pos = mod(pos, resolution);
    pos = pos - resolution * 0.5;

    float cloudShadow = sdfCloud(pos*size + vec2(25.0))-40.0;
    float cloud = sdfCloud(pos*size);
    color = mix(color, vec3(0.0), 0.5*smoothstep(0.0, -100.0, cloudShadow));
    color = mix(vec3(1.0), color, smoothstep(0.0, 1.0, cloud));
  }



  // convert the color from linear color space to sRGB color space, because lighting calculation is done in linear color space
  color = linearTosRGB(color);

  // pow proximation of gamma correction for the sRGB color space
  // color = pow(color, vec3(1.0 / 2.2));

  gl_FragColor = vec4(color, 1.0);
}