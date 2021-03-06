

// hexagon stuff from here - https://www.redblobgames.com/grids/hexagons/#hex-to-pixel
/*
This set of functions is used to help me implement "hexagonal pixelation".
For each pixel, I compute what hexagon it is a part of, then sample points 
from that hexagonal region, and then calculate some metric over the sampled 
points (such as avg luminance, avg color-distance between camera and snapshot, etc)
*/

/*most of the following functions are translations between different types of 
coordinate systems for describing hexagon tiling in 2D, all described in the 
above link
*/
vec2 cube_to_axial(vec3 cube){
    float q = cube.x;
    float r = cube.z;
    return vec2(q, r);
}

vec3 axial_to_cube(vec2 hex){
    float x = hex.x;
    float z = hex.y;
    float y = -x-z;
    return vec3(x, y, z);
}

float round(float v){
    return floor(v+0.5);
}

vec3 cube_round(vec3 cube){
    float rx = round(cube.x);
    float ry = round(cube.y);
    float rz = round(cube.z);

    float x_diff = abs(rx - cube.x);
    float y_diff = abs(ry - cube.y);
    float z_diff = abs(rz - cube.z);

    if (x_diff > y_diff && x_diff > z_diff){
        rx = -ry-rz;
    }
    else if (y_diff > z_diff) {
        ry = -rx-rz;
    } else{
        rz = -rx-ry;
    }

    return vec3(rx, ry, rz);
}

vec2 hex_round(vec2 hex){
    return cube_to_axial(cube_round(axial_to_cube(hex))); 
}

vec2 cube_to_oddr(vec3 cube){
      float col = cube.x + (cube.z - mod(cube.z,2.)) / 2.;
      float row = cube.z;
      return vec2(col, row);
}

vec3 oddr_to_cube(vec2 hex){
      float x = hex.x - (hex.x - mod(hex.x,2.)) / 2.;
      float z = hex.y;
      float y = -x-z;
      return vec3(x, y, z);
}

vec2 hex_to_pixel(vec2 hex, float size){
    float x = size * sqrt(3.) * (hex.x + hex.y/2.);
    float y = size * 3./2. * hex.y;
    return vec2(x, y);
}

vec2 pixel_to_hex(vec2 p, float size){
    float x = p.x;
    float y = p.y;
    float q = (x * sqrt(3.)/3. - y / 3.) / size;
    float r = y * 2./3. / size;
    return vec2(q, r);
}


//This function is important - it returns the center of the hexagon of which 
//the pixel p is a member of. 
vec2 hexCenter2(vec2 p, float size){
    return hex_to_pixel(hex_round(pixel_to_hex(p, size)), size);
}
// end of  borrowed hexagon code


// calculates the luminance value of a pixel
// formula found here - https://stackoverflow.com/questions/596216/formula-to-determine-brightness-of-rgb-color 
vec3 lum(vec3 color){
    vec3 weights = vec3(0.212, 0.7152, 0.0722);
    return vec3(dot(color, weights));
}

//calculate the distance beterrn two colors
// formula found here - https://stackoverflow.com/a/40950076
float colourDistance(vec3 e1, vec3 e2) {
  float rmean = (e1.r + e2.r ) / 2.;
  float r = e1.r - e2.r;
  float g = e1.g - e2.g;
  float b = e1.b - e2.b;
  return sqrt((((512.+rmean)*r*r)/256.) + 4.*g*g + (((767.-rmean)*b*b)/256.));
}

/* calculate the average difference between camera and snapshot for the 
hexagon tile enclosing point p */
float hexDiffAvg(vec2 p, float numHex){
    vec2 p2 = p * numHex;
    vec2 center = hexCenter2(p2, 1.);
    bool contained = false;
    float diff = 0.;
    for(float i = 0.; i < 6.; i++){
        float rad = i * PI / 3.;
        vec2 corner = rotate(vec2(center.x+1., center.y), center, rad);
        for(float j = 0.; j < 3.; j++){
            vec2 samp = mix(center, corner, (0.2*(j+1.))) / numHex;
            vec3 cam = texture2D(channel0, samp).xyz;
            vec3 snap = texture2D(channel3, samp).xyz;
            diff += colourDistance(cam, snap);
        }
    }
    return diff / 18.;
}

/* calculate the average difference between camera and snapshot for the 
hexagon tile enclosing point p */
vec3 hexColorAvg(vec2 p, float numHex){
    vec2 p2 = p * numHex;
    vec2 center = hexCenter2(p2, 1.);
    bool contained = false;
    vec3 col = vec3(0.);
    for(float i = 0.; i < 6.; i++){
        float rad = i * PI / 3.;
        vec2 corner = rotate(vec2(center.x+1., center.y), center, rad);
        for(float j = 0.; j < 3.; j++){
            vec2 samp = mix(center, corner, (0.2*(j+1.))) / numHex;
            vec3 cam = texture2D(channel0, samp).xyz;
            col += cam;
        }
    }
    return col / 18.;
}

/* The function that generates the rotating grid texture. Given a point, it
returns the color for that point. It can be parameterized by time to 
control its speed. The input point can also be transformed at the callsite to 
further distort the texture. */
vec3 diffColor(float time2, vec2 stN){
    stN = rotate(vec2(0.5+sin(time2)*0.5, 0.5+cos(time2)*0.5), stN, sin(time2));
    
    vec2 segGrid = vec2(floor(stN.x*30.0 * sin(time2/7.)), floor(stN.y*30.0 * sin(time2/7.)));

    vec2 xy;
    float noiseVal = rand(stN)*sin(time2/7.) * 0.15;
    if(mod(segGrid.x, 2.) == mod(segGrid.y, 2.)) xy = rotate(vec2(sinN(time2), cosN(time2)), stN.xy, time2 + noiseVal);
    else xy = rotate(vec2(sinN(time2), cosN(time2)), stN.xy, - time2 - noiseVal);
    
    float section = floor(xy.x*30.0 * sin(time2/7.)); 
    float tile = mod(section, 2.);

    float section2 = floor(xy.y*30.0 * cos(time2/7.)); 
    float tile2 = mod(section2, 2.);
    float timeMod = time2 - (1. * floor(time2/1.)); 
    
    return vec3(tile, tile2, timeMod);
}

/* calculate the average luminance of the swirling texture for the 
hexagon tile enclosing point p */
float hexTexAvg(vec2 p, float numHex){
    vec2 p2 = p * numHex;
    vec2 center = hexCenter2(p2, 1.);
    bool contained = false;
    float avgLum = 0.;
    for(float i = 0.; i < 6.; i++){
        float rad = i * PI / 3.;
        vec2 corner = rotate(vec2(center.x+1., center.y), center, rad);
        for(float j = 0.; j < 3.; j++){
            vec2 samp = mix(center, corner, (0.2*(j+1.))) / numHex;
            vec3 tex = diffColor(time / 8., samp);
            avgLum += lum(tex).x;
        }
    }
    return avgLum / 18.;
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

/* bound a number to [low, high] and "wrap" the number back into the range
if it exceeds the range on either side - 
for example wrap(10, 1, 9) -> 8
and wrap (-2, -1, 9) -> 0
*/
float wrap(float val, float low, float high){
    if(val < low) return low + (low-val);
    if(val > high) return high - (val - high);
    return val;
}

float wrap2(float val, float low, float high){
    return mod(val - low, high - low) + low;
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

// bound a number between the limits
float bound(float val, float lower, float upper){
    return max(lower, min(upper, val));
}

/* calculates the average luminance of the block containing the current pixel.
The size of the rectangular tiling and the quantization of the luminance
are both parameters. 
*/
float block(float numBlocks, float quantLevel) {
    vec2 stN = uvN();
    vec3 cam = texture2D(channel0, vec2(1.-stN.x, stN.y)).xyz; 
    vec3 lumC = lum(cam);
    vec2 res = gl_FragCoord.xy / stN;
    vec2 blockSize = res.xy / numBlocks;
    vec2 blockStart = floor(gl_FragCoord.xy / blockSize) * blockSize / res.xy;
    float blockAvgLuma = 0.;
    vec2 counter = blockStart;
    
    vec2 inc = vec2(1. / (numBlocks *100.));
    for(float i = 0.; i < 10.; i += 1.){
        for(float j = 0.; j < 10.; j += 1.){
            blockAvgLuma += lum(texture2D(channel0, vec2(1.-counter.x, counter.y)).xyz).r;
            counter += inc;
        }
    }
    blockAvgLuma /= 100.;
    
    return quant(blockAvgLuma, quantLevel);
}

vec3 blockrgb(float numBlocks, float quantLevel) {
    vec2 stN = uvN();
    vec3 cam = texture2D(channel0, vec2(1.-stN.x, stN.y)).xyz; 
    vec3 lumC = lum(cam);
    vec2 res = gl_FragCoord.xy / stN;
    vec2 blockSize = res.xy / numBlocks;
    vec2 blockStart = floor(gl_FragCoord.xy / blockSize) * blockSize / res.xy;
    vec3 colAvg = vec3(0.);
    vec2 counter = blockStart;
    
    vec2 inc = vec2(1. / (numBlocks *100.));
    for(float i = 0.; i < 10.; i += 1.){
        for(float j = 0.; j < 10.; j += 1.){
            colAvg += texture2D(channel0, vec2(1.-counter.x, counter.y)).xyz;
            counter += inc;
        }
    }
    colAvg /= 100.;
    
    return quant(colAvg, quantLevel);
}

//val assumed between 0 - 1
float scale(float val, float minv, float maxv){
    float range = maxv - minv;
    return minv + val*range;
}

// implement the mapping scheme described in the artist statement
float indMap(float val, float ind){
    return cosN(val * PI * pow(2., ind));
}

/* constructs a series that produces interesting results for mapping,
 particularly when used in the denominator */ 
float twinGeo(float v, float range){
    if(v > 0.5) return (v-0.5) * 2. * range;
    if(v < 0.5) return 1. / (abs(v-0.5) * 2. * range);
    return 1.;
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

bool multiBallCondition(vec2 stN){
    
    float rad = 0.1 + sinN(time/4.)/ 10.;
    bool cond = false;
    
    for (float i = 0.0; i < 10.; i++) {
        vec2 p = vec2(sinN(time * rand(i) * 1.3 + i), cosN(time * rand(i) * 1.1 + i));
        cond = cond || distance(stN, p) < rad;
    }
    
    return cond;
}


vec2 columnWaves(vec2 stN, float numColumns){
    return vec2(wrap(stN.x + sin(quant(stN.x, numColumns)*time*8.)*0.05, 0., 1.), wrap(stN.y + cos(quant(stN.x, numColumns)*5.+time*2.)*0.22, 0., 1.));
}
vec2 rowWaves(vec2 stN, float numColumns){
    return vec2(wrap(stN.x + sin(quant(stN.y, numColumns)*5.+time*2.)*0.22, 0., 1.), wrap(stN.y + cos(quant(stN.y, numColumns)*time*8.)*0.05, 0., 1.));
}

//removed position dependent speed for more order
vec2 columnWaves2(vec2 stN, float numColumns){
    return vec2(wrap(stN.x + sin(time*8.)*0.05, 0., 1.), wrap(stN.y + cos(quant(stN.x, numColumns)*5.+time*2.)*0.22, 0., 1.));
}
vec2 rowWaves2(vec2 stN, float numColumns){
    return vec2(wrap(stN.x + sin(quant(stN.y, numColumns)*5.+time*2.)*0.22, 0., 1.), wrap(stN.y + cos(time*8.)*0.05, 0., 1.));
}

vec2 columnWaves3(vec2 stN, float numColumns, float time2, float power){
    return vec2(wrap(stN.x + sin(time2*8.)*0.05 * power, 0., 1.), wrap(stN.y + cos(quant(stN.x, numColumns)*5.+time2*2.)*0.22 * power, 0., 1.));
}
vec2 rowWaves3(vec2 stN, float numColumns, float time2, float power){
    return vec2(wrap(stN.x + sin(quant(stN.y, numColumns)*5.+time2*2.)*0.22 * power, 0., 1.), wrap(stN.y + cos(time2*8.)*0.05 * power, 0., 1.));
}

vec2 rowColWave(vec2 stN, float div, float time2, float power){
    for (int i = 0; i < 1; i++) {
        stN = rowWaves3(stN, div, time2, power);
        stN = columnWaves3(stN, div, time2, power);
    }
    return stN;
}

vec3 colorMix(float v){
    vec3 colors[5];
    colors[0] = vec3(192.,244.,255.)/255.;
    colors[1] = vec3(216.,130.,191.)/255.;
    colors[2] = vec3(223.,204.,91.)/255.;
    colors[3] = vec3(167.,180.,199.)/255.;
    colors[4] = vec3(9.,169.,20.)/255.;
    colors[0] = vec3(255,225,102)/255.;
    colors[1] = vec3(255,209,18)/255.;
    colors[2] = vec3(133,0,0)/255.;
    colors[3] = vec3(99,0,0)/255.;
    colors[4] = vec3(58,0,0)/255.;
    float v2 = mod(v, 5.);
    float v3 = mod(v, 1.);
    float mixfactor = 1.;
    if((0. <= v2) && (v2 < 1.)) return mix(colors[0], colors[1], v3*mixfactor);
    else if((1. <= v2) && (v2 < 2.)) return mix(colors[1], colors[2], v3*mixfactor);
    else  if((2. <= v2) && (v2 < 3.)) return mix(colors[2], colors[3], v3*mixfactor);
    else if((3. <= v2) && (v2 < 4.)) return mix(colors[3], colors[4], v3*mixfactor);
    else if((4. <= v2) && (v2 <= 5.)) return mix(colors[4], colors[0], v3*mixfactor);
    else return black;
}

void main () {

    //the current pixel coordinate 
    vec2 stN = uvN();
    vec2 camN = vec2(1.- stN.x, stN.y);
    
    // vec3 c;
    // float decay = 0.96;
    // float feedback;
    // vec3 cam = texture2D(channel0, stN).xyz; 
    // vec3 camWarp = texture2D(channel0, coordWarp(stN)).xyz;
    // vec3 camWave = texture2D(channel0, rowWaves(stN, 0.)).xyz;
    
    // vec3 waveWarp = texture2D(channel0, rowWaves(columnWaves(rowWaves(columnWaves(camN, 2.), 2.), 2.), 2.)).xyz;
    // float div = 1.+sinN(time/5.)*50.;
    // waveWarp = texture2D(channel0, rowWaves2(columnWaves2(rowWaves2(columnWaves2(camN, div), div), div), div)).xyz;


    // float lastFeedback = texture2D(backbuffer, vec2(stN.x, stN.y)).a; 
    // bool condition = multiBallCondition(stN); distance(in1.xy, stN) < .1;
    // vec3 trail = camWave; swirl(time/5., stN) ; cam;
    // vec3 foreGround = cam; mod(camWarp*(0.8 + sinN(time))*3., 1.);
    float t = time + bands.w;
    vec2 deepTileWave = rowColWave(camN * (1. + sinN(t/4.5)*5.), 1. + sinN(t/2.3) * 20., t, 0.1 + sinN(t));
    vec2 tileWaveRot = wrap(rotate(deepTileWave, vec2(sinN(t/3.), cosN(t/3.)), t)*(1. + sinN(t/5.)*10.), 0., 1.);
    // vec2 tileWaveRot2 = wrap(rotate(deepTileWave, vec2(0.5), randWalk/90.)*5., 0., 1.);
    // vec3 wrapTile = texture2D(channel0, tileWaveRot2).rgb;
    // vec3 warpswirl = swirl(time/10., deepTileWave);
    
    stN = tileWaveRot;
    // stN = coordWarp(stN);
    // float randval = rand(vec2(quant(stN.x+time/10., 10.), quant(stN.y+time/7., 70.)));
    // float randval2 = rand(vec2(quant(stN.x+sin(time)/6., 10.), quant(stN.y+sin(time)/5., 70.)));
    // float randval3 = rand(vec2(quant(time, 5.), quant(stN.x+sin(time/1.)/4., 20.+sinN(time/5.)*51.) + quant(stN.y+cos(time/1.)/4.,  20.+sinN(time/5.)*50.)));
    float randval4 = rand(vec2(quant(sinN(time/15.), 10.), quant(stN.x, 10.) + quant(stN.y, 10.))) > 0.25 + sinN(time/5.)/2. ? 1. : 0.;
    
    
    // // implement the trailing effectm using the alpha channel to track the state of decay 
    // if(condition){
    //     if(lastFeedback < 1.1) { 
    //         feedback = 1.;
    //         c = trail; 
    //     } 
    //     // else {
    //     //     feedback = lastFeedback * decay;
    //     //     c = mix(snap, bb, lastFeedback);
    //     // }
    // }
    // else {
    //     feedback = lastFeedback * decay;
    //     if(lastFeedback > 0.4) {
    //         c = mix(foreGround, trail, lastFeedback); 
    //     } else {
    //         feedback = 0.;
    //         c = foreGround;
    //     }
    // }
    vec3 c = colorMix(randval4 * (1.1+sinN(time/7.)*2.8) + time/5.);
    
    gl_FragColor = vec4(vec3(c), 1.);
}

