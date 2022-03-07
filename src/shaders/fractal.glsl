/**
DO NOT EDIT THIS FILE!

It should be only used as a template for creating new ray-marcher.
*/

#define MAX_STEPS 100
#define MAX_DIST 100.
#define SURF_DIST .001
#define T uTick * 0.01

precision mediump float;

varying vec2 uv;

uniform float uTick;
uniform float uAspectRatio;
uniform vec2 uMouse;
uniform vec2 uResolution;
uniform sampler2D uMatcap1;
uniform sampler2D uMatcap2;

// helper utitlity functions

mat2 rotate(float angle) {
  float s = sin(angle);
  float c = cos(angle);
  return mat2(c, -s, s, c);
}

vec2 matcap(vec3 eye, vec3 normal) {
  vec3 reflected = reflect(eye, normal);
  float m = 2.8284271247461903 * sqrt(reflected.z + 1.0);
  return reflected.xy / m + 0.5;
}

float hash21(vec2 point) {
  point = fract(point * vec2(123.9898, 278.233));
  point += dot(point, point + 23.4);
  return fract(point.x * point.y);
}

// smooth min functions

float smin(float a, float b, float k) {
  float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
  return mix(b, a, h) - k * h * (1.0 - h);
}

// sdf

float sdBox(vec3 point, vec3 size, float radius) {
  point = fract(point) - 0.5;
  point.yz *= rotate(T);
  point.xy *= rotate(T);
  point.y += sin(T) * 0.2;
  point = abs(point) - size;
  return length(max(point, 0.0)) + min(max(point.x, max(point.y, point.z)), 0.0) - radius;
}

float sdSphere(vec3 point, float radius) {
  point = fract(point) - 0.5;
  point.yz *= rotate(T * 0.01);
  return length(point) - radius;
}

// transformation
vec3 transform(vec3 point) {
  point.z -= T;
  point.xy *= rotate(point.z * 0.1);
  return point;
}

// ray march functions

float getDistance(vec3 point) {
  point = transform(point);
  float d = sdBox(point, vec3(0.1), 0.05);
  return d * 0.8;
}

float rayMarch(vec3 rayOrigin, vec3 rayDirection) {
  float dO = 0.;

  for(int i = 0; i < MAX_STEPS; i++) {
    vec3 point = rayOrigin + rayDirection * dO;
    float dS = getDistance(point);
    dO += dS;
    if(dO > MAX_DIST || abs(dS) < SURF_DIST)
      break;
  }

  return dO;
}

vec3 getNormal(vec3 point) {
  float d = getDistance(point);
  vec2 epsilon = vec2(.001, 0);
  vec3 n = d - vec3(getDistance(point - epsilon.xyy), getDistance(point - epsilon.yxy), getDistance(point - epsilon.yyx));
  return normalize(n);
}

vec3 getRayDirection(vec2 uv, vec3 cameraPosition, vec3 lookatPoint, float zoom) {
  vec3 forward = normalize(lookatPoint - cameraPosition);
  vec3 right = normalize(cross(vec3(0, 1, 0), forward));
  vec3 up = cross(forward, right);
  vec3 center = forward * zoom;
  vec3 pointOnScreen = center + uv.x * right + uv.y * up;
  return normalize(pointOnScreen);
}

void main() {
  vec2 pos = (uv - vec2(0.5)) * vec2(uAspectRatio, 1);
  vec2 mouse = uMouse / uResolution;

  vec3 rayOrigin = vec3(0, 3, -3);
  rayOrigin.yz *= rotate(-mouse.y * 3.14 + 1.);
  rayOrigin.xz *= rotate(-mouse.x * 6.2831);

  vec3 rayDirection = getRayDirection(pos, rayOrigin, vec3(0, 0., 0), 1.0);
  vec3 color = vec3(0);

  float d = rayMarch(rayOrigin, rayDirection);
  if(d < MAX_DIST) {
    vec3 p = rayOrigin + rayDirection * d;
    vec3 n = getNormal(p);

    p = transform(p);

    vec2 matcapPos = matcap(rayDirection, n);
    vec3 color1 = texture2D(uMatcap1, matcapPos).rgb;
    vec3 color2 = texture2D(uMatcap2, matcapPos).rgb;
    color = mix(color1, color2, smoothstep(1.0, 10.0, d));
    // float bump = texture2D(uMatcap1, matcapPos).r;
    // p += bump * 10.0;

    float diffuseLighting = dot(n, normalize(vec3(0.0, 1.0, 1.0))) * .5 + .5;
    // color = vec3(diffuseLighting);
    color = mix(color, vec3(0.0), smoothstep(1.0, 14.0, d)) * diffuseLighting;
  }

  color = mix(color, vec3(0.2), smoothstep(0.1, 0.65, dot(pos, pos)));

  // gamma correction
  color = pow(color, vec3(.4545));

  gl_FragColor = vec4(color, 1.0);
}