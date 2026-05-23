uniform vec2 resolution;
uniform float time;

//--------------------------------------------------------------------------
varying vec4 vClipPosition;
//--------------------------------------------------------------------------

vec3 palette(float t, vec3 a, vec3 b, vec3 c, vec3 d)
{
    return a + b * cos(6.28318 * (c * t+d));
}

vec3 palette(float t)
{
    //vec3 a = vec3(0.5, 0.5, 0.5);
    //vec3 b = vec3(0.5, 0.5, 0.5);
    //vec3 c = vec3(1.0, 1.0, 1.0);
    //vec3 d = vec3(0.263, 0.416, 0.557);
    
    vec3 a = vec3(0.520, 0.718, 0.748);
    vec3 b = vec3(1.003, 0.414, 0.173);
    vec3 c = vec3(1.414, 0.801, 0.753);
    vec3 d = vec3(-0.363, -0.733, -0.293);

    return a + b * cos(6.28318 * (c * t+d));
}


void main()
{
    // vec2 uv = (gl_FragCoord.xy*2.0 - resolution.xy)/resolution.y;

    //uv *= 2.0;
    //uv = fract(uv);
    //uv -= 0.5;


    //--------------------------------------------------------------------------
    // 1. Perspective divide and convert to range [-1, 1]
    vec3 ndc = vClipPosition.xyz / vClipPosition.w;
    
    // 2. Remap to [0, 1] range (equivalent to normalized UVs)
    vec2 nUv = ndc.xy * 0.5 + 0.5;
    
    // 3. (Optional) Get pixel coordinates equivalent to gl_FragCoord.xy
    vec2 fragCoord = nUv * resolution;

    vec2 uv = (fragCoord*2.0 - resolution.xy)/resolution.y;
    //--------------------------------------------------------------------------


    
    vec2 uv0 = uv;
    
    vec3 finalColor = vec3(0.0);
    
    for(float i = 0.0; i < 4.0; i++)
    {
        //uv = fract(uv * 2.0) - 0.5;
        uv = fract(uv * 1.5) - 0.5;

        float d = length(uv);
        float d0 = length(uv0);
            
        d = d * exp(-d0);
        
        //vec3 colorVariant = vec3(1.0, 2.0, 3.0);
        //vec3 colorVariant = palette(d);
        //vec3 colorVariant = palette(d + time);
        //vec3 colorVariant = palette(d0 + time);
        //vec3 colorVariant = palette(d0 + time*.4);
        vec3 colorVariant = palette(d0 + i*.4 + time*.4);

        //d -= 0.5;
        d = sin(d*8.0 + time)/8.;
        d = abs(d);

        //d = step(0.1, d);

        //d = smoothstep(0.0, 0.1, d);
        //d = 0.02 / d;
        d = 0.01 / d;
        d = pow(d, 1.2);


        finalColor += colorVariant*d;
    }
    gl_FragColor = vec4(finalColor,1.0);
}
