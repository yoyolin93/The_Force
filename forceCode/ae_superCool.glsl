


//calculate the distance beterrn two colors
// formula found here - https://stackoverflow.com/a/40950076
float colourDistance(vec3 e1, vec3 e2) {
  float rmean = (e1.r + e2.r ) / 2.;
  float r = e1.r - e2.r;
  float g = e1.g - e2.g;
  float b = e1.b - e2.b;
  return sqrt((((512.+rmean)*r*r)/256.) + 4.*g*g + (((767.-rmean)*b*b)/256.));
}

vec2 coordWarp(vec2 stN){
    vec2 warp = stN;
    
    float rad = .5;
    
    for (float i = 0.0; i < 20.; i++) {
        vec2 p = vec2(sinN(time/5. * rand(i) * 1.3 + i), cosN(time/5. * rand(i) * 1.1 + i));
        warp = length(p - stN) <= rad ? mix(warp, p, 1. - length(stN - p)/rad)  : warp;
    }
    
    return warp;
}

float wrap3(float val, float low, float high){
    float range  = high - low;
    if(val > high){
        float dif = val-high;
        float difMod = mod(dif, range);
        float numWrap = dif/range - difMod;
        if(mod(numWrap, 2.) == 0.){
            return high - difMod;
        } else {
            return low + difMod;
        }
    }
    if(val < low){
        float dif = low-val;
        float difMod = mod(dif, range);
        float numWrap = dif/range - difMod;
        if(mod(numWrap, 2.) == 0.){
            return low + difMod;
        } else {
            return high - difMod;
        }
    }
    return val;
}
vec2 wrap(vec2 val, float low, float high){
    return vec2(wrap3(val.x, low, high), wrap3(val.y, low, high));
}

vec3 wrap(vec3 val, float low, float high){
    return vec3(wrap3(val.x, low, high), wrap3(val.y, low, high), wrap3(val.z, low, high));
}

// quantize and input number [0, 1] to quantLevels levels
float quant(float num, float quantLevels){
    float roundPart = floor(fract(num*quantLevels)*2.);
    return (floor(num*quantLevels)+roundPart)/quantLevels;
}

// same as above but for vectors, applying the quantization to each element
vec3 quant(vec3 num, float quantLevels){
    vec3 roundPart = floor(fract(num*quantLevels)*2.);
    return (floor(num*quantLevels)+roundPart)/quantLevels;
}

// same as above but for vectors, applying the quantization to each element
vec2 quant(vec2 num, float quantLevels){
    vec2 roundPart = floor(fract(num*quantLevels)*2.);
    return (floor(num*quantLevels)+roundPart)/quantLevels;
}

void main () {

    int cue = 1;

    //the current pixel coordinate 
    vec2 stN = uvN();
    
    //the current pixel in camera coordinate (this is sometimes transformed)
    vec2 camPos = vec2(1.- stN.x, stN.y);


    // the decay factor of the trails
    float decay = 0.97;
  
    // the color of the current (post zoom) pixel in the snapshot
    vec3 snap = texture2D(channel3, camPos).rgb;

    //the color of the current (post zoom) pixel in the live webcam input
    vec3 cam = texture2D(channel0, camPos).rgb;  

    //the color of the last drawn frame (used to implement fading trails)
    vec3 bb = texture2D(backbuffer, vec2(stN.x, stN.y)).rgb;


    
    vec3 coll = texture2D(channel1, stN).rgb;

    // the vector that will hold the final color value for this pixel
    vec3 c;

    //how "faded" the current pixel is into the background (used to implement fading trails)
    float lastFeedback = texture2D(backbuffer, vec2(stN.x, stN.y)).a; 

    //the value for how much the current pixel will be "faded" into the background
    float feedback;
    // how high the difference is between camera and snapshot for the current pixel (not used)
    float pointDiff = colourDistance(cam, snap);
    
    
    vec3 trail = coll;
    vec3 foreGround = cam;
    
    float diffThresh = 0.8;
    
    float diffStyle = pointDiff;
    
    if(cue == 2 ){
        diffThresh = 0.45;
        diffStyle = pointDiff;
        decay = 0.99;
        foreGround = cam;
        trail = coll;
        // implement the trailing effectm using the alpha channel to track the state of decay 
        if(diffStyle > diffThresh){
            if(lastFeedback < 1.) {
                feedback = 1.;
                c = trail; 
            } 
            // else {
            //     feedback = lastFeedback * decay;
            //     c = mix(snap, bb, lastFeedback);
            // }
        }
        else {
            feedback = lastFeedback * decay;
            if(lastFeedback > 0.8) {
                c = mix(foreGround, trail, lastFeedback); 
            } else {
                feedback = 0.;
                c = foreGround;
            }
        }
    }
    if(cue == 1 ){
        diffThresh = 0.3;
        vec2 mouseN = mouse.zw / resolution.xy / 2.;
        mouseN = vec2(mouseN.x, 1. - mouseN.y);
        vec3 chromaKeyColor = texture2D(channel0, vec2(1.-mouseN.x, mouseN.y)).rgb;
        if(colourDistance(cam, chromaKeyColor) < diffThresh ){
            c = coll;
        }
        else {
            c = cam;
        }
    }
    
    
    
    gl_FragColor = vec4(vec3(c), feedback);
}