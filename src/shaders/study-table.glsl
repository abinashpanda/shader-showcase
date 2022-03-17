/**
DO NOT EDIT THIS FILE!

It should be only used as a template for creating new ray-marcher.
*/

#define MAX_STEPS 100
#define MAX_DIST 100.
#define SURF_DIST .001
#define ZOOM 2.0

precision mediump float;

varying vec2 uv;

uniform float uTick;
uniform float uAspectRatio;
uniform vec2 uMouse;
uniform vec2 uResolution;

// helper utitlity functions

mat2 rotate(float angle) {
  float s = sin(angle);
  float c = cos(angle);
  return mat2(c, -s, s, c);
}

float dot2(vec2 p) {
  return dot(p, p);
}

// smooth min functions

float smin(float a, float b, float k) {
  float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
  return mix(b, a, h) - k * h * (1.0 - h);
}

// sdf

float sdBox(vec3 point, vec3 size) {
  point = abs(point) - size;
  return length(max(point, 0.)) + min(max(point.x, max(point.y, point.z)), 0.);
}

float sdRoundedCylinder(vec3 point, float ra, float rb, float h) {
  vec2 d = vec2(length(point.xz) - 2.0 * ra + rb, abs(point.y) - h);
  return min(max(d.x, d.y), 0.0) + length(max(d, 0.0)) - rb;
}

float sdCappedCylinder(vec3 point, float h, float r) {
  vec2 d = abs(vec2(length(point.xz), point.y)) - vec2(h, r);
  return min(max(d.x, d.y), 0.0) + length(max(d, 0.0));
}

float sdCappedCone(vec3 point, float h, float r1, float r2) {
  vec2 q = vec2(length(point.xz), point.y);
  vec2 k1 = vec2(r2, h);
  vec2 k2 = vec2(r2 - r1, 2.0 * h);
  vec2 ca = vec2(q.x - min(q.x, (q.y < 0.0) ? r1 : r2), abs(q.y) - h);
  vec2 cb = q - k1 + k2 * clamp(dot(k1 - q, k2) / dot2(k2), 0.0, 1.0);
  float s = (cb.x < 0.0 && ca.y < 0.0) ? -1.0 : 1.0;
  return s * sqrt(min(dot2(ca), dot2(cb)));
}

// scene specific sdf

float sdTableLeg(vec3 point, vec3 pos) {
  return sdBox(point + pos, vec3(0.03, 0.5, 0.03)) - 0.02;
}

// ray march functions

float getDistance(vec3 point) {
  float tableTop = sdBox(point, vec3(1, 0.01, 0.5)) - 0.05;

  float tableLeg1 = sdTableLeg(point, vec3(-.8, 0.5, -0.4));
  float tableLeg2 = sdTableLeg(point, vec3(.8, 0.5, -0.4));
  float tableLeg3 = sdTableLeg(point, vec3(.8, 0.5, 0.4));
  float tableLeg4 = sdTableLeg(point, vec3(-.8, 0.5, 0.4));
  float tableLeg = min(tableLeg1, tableLeg2);
  tableLeg = min(tableLeg, tableLeg3);
  tableLeg = min(tableLeg, tableLeg4);

  float lampBase = sdCappedCylinder(point, 0.15, 0.01);
  float lampPole = sdCappedCylinder(point - vec3(0.0, 0.17, 0.0), 0.025, 0.15);
  float lampCover = sdCappedCone(point - vec3(0.0, 0.4, 0.0), 0.1, 0.2, 0.1);

  float lamp = smin(lampPole, lampBase, 0.03);
  lamp = min(lamp, lampCover);

  float d = min(tableTop, tableLeg);
  d = min(d, lamp);
  // float d = lamp;

  return d;
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

  vec3 rayDirection = getRayDirection(pos, rayOrigin, vec3(0, 0., 0), ZOOM);
  vec3 color = vec3(0);

  float d = rayMarch(rayOrigin, rayDirection);
  if(d < MAX_DIST) {
    vec3 p = rayOrigin + rayDirection * d;
    vec3 n = getNormal(p);
    // vec3 r = reflect(rayDirection, n);

    float diffuseLighting = dot(n, normalize(vec3(1, 2, 3))) * .5 + .5;
    color = vec3(diffuseLighting);
  }

  // gamma correction
  color = pow(color, vec3(.4545));

  gl_FragColor = vec4(color, 1.0);
}