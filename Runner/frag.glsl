#version 420 core
//#extension GL_EXT_control_flow_attributes : require
#extension GL_EXT_shader_image_load_store : require

out vec4 frag_color;

uniform vec3 screen_size; // z is internal counter
uniform mat4 inv_cam_proj;
uniform mat4 inv_cam_view;
layout(rgba32f) uniform image2D out_img;

#define PI 3.1415926
#define EPS 1e-3
#define T_MAX 1e6

struct Material {
  vec3 albedo;
  vec3 specular;
  float spec_chance;
  float roughness;
  float emmitence;
  float ior;
  uint effect;
};

struct Ray {
  vec3 origin;
  vec3 dir;
};

struct Sphere {
  vec3 pos;
  float r;
  uint mat;
};

vec3 LessThan(vec3 f, float value)
{
    return vec3(
        (f.x < value) ? 1.0f : 0.0f,
        (f.y < value) ? 1.0f : 0.0f,
        (f.z < value) ? 1.0f : 0.0f);
}
 
vec3 LinearToSRGB(vec3 rgb)
{
    rgb = clamp(rgb, 0.0f, 1.0f);
     
    return mix(
        pow(rgb, vec3(1.0f / 2.4f)) * 1.055f - 0.055f,
        rgb * 12.92f,
        LessThan(rgb, 0.0031308f)
    );
}
 
vec3 SRGBToLinear(vec3 rgb)
{
    rgb = clamp(rgb, 0.0f, 1.0f);
     
    return mix(
        pow(((rgb + 0.055f) / 1.055f), vec3(2.4f)),
        rgb / 12.92f,
        LessThan(rgb, 0.04045f)
    );
}

uint wang_hash(inout uint seed) {
    seed = uint(seed ^ uint(61)) ^ uint(seed >> uint(16));
    seed *= uint(9);
    seed = seed ^ (seed >> 4);
    seed *= uint(0x27d4eb2d);
    seed = seed ^ (seed >> 15);
    return seed;
}

// ACES tone mapping curve fit to go from HDR to LDR
//https://knarkowicz.wordpress.com/2016/01/06/aces-filmic-tone-mapping-curve/
vec3 ACESFilm(vec3 x)
{
    float a = 2.51f;
    float b = 0.03f;
    float c = 2.43f;
    float d = 0.59f;
    float e = 0.14f;
    return clamp((x*(a*x + b)) / (x*(c*x + d) + e), 0.0f, 1.0f);
}

float rand3D(in vec3 co) {
    return fract(sin(dot(co.xyz ,vec3(12.9898,78.233,144.7272))) * 43758.5453);
}

// Generates a seed for a random number generator from 2 inputs plus a backoff
// https://github.com/nvpro-samples/optix_prime_baking/blob/332a886f1ac46c0b3eea9e89a59593470c755a0e/random.h
// https://github.com/nvpro-samples/vk_raytracing_tutorial_KHR/tree/master/ray_tracing_jitter_cam
// https://en.wikipedia.org/wiki/Tiny_Encryption_Algorithm
uint init_rand_seed(uint val0, uint val1) {
  uint v0 = val0, v1 = val1, s0 = 0;
  //[[unroll]] hopefully unrolls automatically 
  for (uint n = 0; n < 16; n++){
    s0 += 0x9e3779b9;
    v0 += ((v1 << 4) + 0xa341316c) ^ (v1 + s0) ^ ((v1 >> 5) + 0xc8013ea4);
    v1 += ((v0 << 4) + 0xad90777d) ^ (v0 + s0) ^ ((v0 >> 5) + 0x7e95761e);
  }

  return v0;
}

float rand(inout uint state) {
    return float(wang_hash(state)) / 4294967296.0;
}

vec3 rand_vec(inout uint state) {
  float z = rand(state) * 2.0f - 1.0f;
  float a = rand(state) * 2 * PI;
  float r = sqrt(1.0f - z * z);
  float x = r * cos(a);
  float y = r * sin(a);
  return vec3(x, y, z);
}

// schlick's approximation of the fresnel effect
float fresnel_coe(float n1, float n2, vec3 normal, vec3 incident, float f0, float f90){
  float r0 = (n1-n2) / (n1+n2);
  r0 *= r0;
  float cosX = -dot(normal, incident);
  if (n1 > n2) {
    float n = n1/n2;
    float sinT2 = n*n*(1.0-cosX*cosX);
    // Total internal reflection
    if (sinT2 > 1.0)
      return f90;
    cosX = sqrt(1.0-sinT2);
  }
  float x = 1.0-cosX;
  float ret = r0+(1.0-r0)*x*x*x*x*x;
 
  return mix(f0, f90, ret);
}

#define NUM_SPHERES 13
#define NUM_MATERIALS 9

Sphere spheres[NUM_SPHERES];
Material mats[NUM_MATERIALS];

uint sphere_count = NUM_SPHERES;
float hit_sphere(in Sphere sphere, Ray ray) {
  float t = -1.0;
  vec3 rc = ray.origin - sphere.pos;
  float c = dot(rc, rc) - (sphere.r * sphere.r);
  float b = dot(ray.dir, rc);
  float d = b*b - c;
  if(d > 0.0) {
    t = -b - sqrt(abs(d));
    return t;
  } else {
    return -1.0;
  }
}

float intersect_scene(inout uint sphere, Ray ray) {
  float mint = T_MAX;
  sphere = 0;
  for(int i = 0; i < sphere_count; ++i) {
    float t = hit_sphere(spheres[i], ray);
    if(t > 0 && t < mint) {
      mint = t;
      sphere = i;
    }
  }
  return (mint >= T_MAX) ? -1 : mint;
}

Ray gen_ray(inout uint rng_state) {
  float focal_len = sqrt(screen_size.x*screen_size.x + screen_size.y*screen_size.y) / ( 2*tan( radians(45/2) ) );
  vec2 jitter = vec2(rand(rng_state), rand(rng_state));
  vec2 pixel_center = gl_FragCoord.xy + jitter;
  vec2 uv = pixel_center / screen_size.xy;
  uv = uv * 2.0 - 1.0;
  vec4 origin = inv_cam_view * vec4(0,0,0,1);
  vec4 target = inv_cam_proj * vec4(uv.x, uv.y, focal_len, 1);
  vec4 dir = inv_cam_view * vec4(normalize(target.xyz), 0);
  Ray ray;
  ray.dir = dir.xyz;
  ray.origin = origin.xyz;
  return ray;
}

void get_effect(inout Material mat, in vec3 inter_p) {
  switch(mat.effect) {
    case 0:
      break;
    case 1:
      if(rand3D(round(inter_p)) > 0.70) { // pixel light effect
		mat.emmitence = 0.7;
      } else {
		mat.emmitence = 0.2;
      }
      break;
    default:
       break;
  }
}

// not physically accurate, but still looks good
vec3 brdf(inout Ray in_ray, Material mat, vec3 normal, inout uint rng_state ){
  float spec_prob = mat.spec_chance;
  if(spec_prob > 0) {
    spec_prob = fresnel_coe(1.0, mat.ior, in_ray.dir, normal, mat.spec_chance, 1.0);
  }
  spec_prob = (rand(rng_state) < spec_prob) ? 1.0f : 0.0f;
  vec3 diff_ray = normalize(normal + rand_vec(rng_state));
  vec3 spec_ray = reflect(in_ray.dir, normal);
  spec_ray = normalize(mix(spec_ray, diff_ray, mat.roughness*mat.roughness));
  in_ray.dir = mix(diff_ray, spec_ray, spec_prob); // glossy outgoing ray
  return mix(mat.albedo, mat.specular, spec_prob);
}

vec3 calc_sample(uint max_bounces, inout uint rng_state) {
  vec3 accumulator = vec3(0);
  vec3 mask = vec3(1);
  
  Ray ray = gen_ray(rng_state);
  uint id;
  for(int b = 0; b < max_bounces; ++b) {
    float t = intersect_scene(id, ray);
    if(t < EPS) break;
    vec3 inter_p =  ray.origin + ray.dir*t;
    
    Material mat = mats[spheres[id].mat];
    
    get_effect(mat, inter_p);
    
    vec3 normal = normalize(inter_p - spheres[id].pos);
    ray.origin = inter_p;
    
    vec3 throughput = brdf(ray, mat, normal, rng_state);
    accumulator += (mask * mat.emmitence * mat.albedo);
    mask *= throughput;

    // russian roulette
    float p = max(mask.r, max(mask.g, mask.b));
    if(rand(rng_state) > p)
     break;
    mask *= 1.0/p; // weight samples based on chance of terminating
  }
  return accumulator;
}

#define WHITE_DIFF 0
#define MIRROR 1
#define PIXEL_LIGHT 2
#define RED_DIFF 3
#define GREEN_DIFF 4
#define GOLD_SPEC 5
#define WHITE_SPEC 6
#define EMITTING_SPEC 7
#define SILVER_SPEC 8

void load_mats() {
  { // init scene
    mats[0].albedo = vec3(1);
    mats[0].emmitence = 0;
    mats[0].effect = 0;
    mats[0].specular = vec3(0);
    mats[0].spec_chance = 0;
    mats[0].roughness = 0;
    mats[0].ior = 1;

    mats[1].albedo = vec3(1);
    mats[1].emmitence = 0;
    mats[1].effect = 0;
    mats[1].specular = vec3(1);
    mats[1].spec_chance = 1.0;
    mats[1].roughness = 0.05;
    mats[1].ior = 1;
    
    mats[2].albedo = vec3(1);
    mats[2].emmitence = 0.25;
    mats[2].effect = 1;
    mats[2].specular = vec3(0);
    mats[2].spec_chance = 0;
    mats[2].roughness = 0;
    mats[2].ior = 1;

    mats[3].albedo = vec3(0.7,0,0);
    mats[3].emmitence = 0;
    mats[3].effect = 0;
    mats[3].specular = vec3(0);
    mats[3].spec_chance = 0;
    mats[3].roughness = 0;
    mats[3].ior = 1;

    mats[4].albedo = vec3(0,0.7,0);
    mats[4].emmitence = 0;
    mats[4].effect = 0;
    mats[4].specular = vec3(0);
    mats[4].spec_chance = 0;
    mats[4].roughness = 0;
    mats[4].ior = 1;

    mats[5].albedo = vec3(212.0/255.0,175.0/255.0,55.0/255.0);
    mats[5].emmitence = 0;
    mats[5].effect = 0;
    mats[5].specular = mats[5].albedo;
    mats[5].spec_chance = 0.7;
    mats[5].roughness = 0.5;
    mats[5].ior = 1;

    mats[6].albedo = vec3(0.7,0.7,0.7);
    mats[6].emmitence = 0;
    mats[6].effect = 1;
    mats[6].specular = vec3(1);
    mats[6].spec_chance = 0.5;
    mats[6].roughness = 0.2;
    mats[6].ior = 1;
	
	mats[7].albedo = vec3(1);
    mats[7].emmitence = 0.2;
    mats[7].effect = 0;
    mats[7].specular = vec3(1);
    mats[7].spec_chance = 0.5;
    mats[7].roughness = 0.2;
    mats[7].ior = 1;
	
	mats[8].albedo = vec3(192.0/255.0,192.0/255.0,192.0/255.0);
    mats[8].emmitence = 0;
    mats[8].effect = 0;
    mats[8].specular = mats[8].albedo;
    mats[8].spec_chance = 0.7;
    mats[8].roughness = 0.5;
    mats[8].ior = 1;
  }
}

void load_scene1() {
  const float room_height = 15.0f;
  const float room_width = 15.0f;
  const float wall_r = 1000;

  spheres[0].pos = vec3(0, -wall_r, 0); // bottom floor
  spheres[0].r = wall_r;
  spheres[0].mat = PIXEL_LIGHT;

  spheres[1].pos = vec3(0, room_height+wall_r, 0); // top ceiling
  spheres[1].r = wall_r;
  spheres[1].mat = MIRROR;

  spheres[2].pos = vec3(room_width/2 + wall_r, 0, 0); // side wall
  spheres[2].r = wall_r;
  spheres[2].mat = MIRROR;

  spheres[3].pos = vec3(-room_width/2 - wall_r, 0, 0); // side wall
  spheres[3].r = wall_r;
  spheres[3].mat = MIRROR;

  spheres[4].pos = vec3(0, 0, room_width/2 + wall_r); // front wall
  spheres[4].r = wall_r;
  spheres[4].mat = MIRROR;

  spheres[5].pos = vec3(0, 0, -room_width/2 - wall_r); // back wall
  spheres[5].r = wall_r;
  spheres[5].mat = MIRROR;

  spheres[6].pos = vec3(0, 1, 0);
  spheres[6].r = 1;
  spheres[6].mat = GOLD_SPEC;

  spheres[7].pos = vec3(0, 5, 0);
  spheres[7].r = 2;
  spheres[7].mat = MIRROR;
  
  spheres[8].pos = vec3(0, 9, 0);
  spheres[8].r = 1;
  spheres[8].mat = GOLD_SPEC;
  
  spheres[9].pos = vec3(4, 5, 0);
  spheres[9].r = 1;
  spheres[9].mat = GOLD_SPEC;
  
  spheres[10].pos = vec3(-4, 5, 0);
  spheres[10].r = 1;
  spheres[10].mat = GOLD_SPEC;
  
  spheres[11].pos = vec3(0, 5, 4);
  spheres[11].r = 1;
  spheres[11].mat = GOLD_SPEC;
  
  spheres[12].pos = vec3(0, 5, -4);
  spheres[12].r = 1;
  spheres[12].mat = GOLD_SPEC;
  
  sphere_count = 13;
}

void load_scene2() {
  const float room_height = 15.0f;
  const float room_width = 15.0f;
  const float wall_r = 1000;

  spheres[0].pos = vec3(0, -wall_r, 0); // bottom floor
  spheres[0].r = wall_r;
  spheres[0].mat = WHITE_DIFF;

  spheres[1].pos = vec3(0, room_height+wall_r, 0); // top ceiling
  spheres[1].r = wall_r;
  spheres[1].mat = WHITE_DIFF;

  spheres[2].pos = vec3(room_width/2 + wall_r, 0, 0); // side wall
  spheres[2].r = wall_r;
  spheres[2].mat = PIXEL_LIGHT;

  spheres[3].pos = vec3(-room_width/2 - wall_r, 0, 0); // side wall
  spheres[3].r = wall_r;
  spheres[3].mat = EMITTING_SPEC;

  spheres[4].pos = vec3(0, 0, room_width/2 + wall_r); // front wall
  spheres[4].r = wall_r;
  spheres[4].mat = WHITE_DIFF;

  spheres[5].pos = vec3(0, 0, -room_width/2 - wall_r); // back wall
  spheres[5].r = wall_r;
  spheres[5].mat = WHITE_DIFF;

  spheres[6].pos = vec3(0, 1, 4);
  spheres[6].r = 1;
  spheres[6].mat = WHITE_DIFF;

  spheres[7].pos = vec3(0, 2, -4);
  spheres[7].r = 2;
  spheres[7].mat = WHITE_DIFF;
  
  sphere_count = 8;
}

void load_scene3() {
  const float room_height = 20.0f;
  const float room_width = 30.0f;
  const float wall_r = 1000;

  spheres[0].pos = vec3(0, -wall_r, 0); // bottom floor
  spheres[0].r = wall_r;
  spheres[0].mat = WHITE_DIFF;

  spheres[1].pos = vec3(0, room_height+wall_r, 0); // top ceiling
  spheres[1].r = wall_r;
  spheres[1].mat = WHITE_DIFF;

  spheres[2].pos = vec3(room_width/2 + wall_r, 0, 0); // side wall
  spheres[2].r = wall_r;
  spheres[2].mat = PIXEL_LIGHT;

  spheres[3].pos = vec3(-room_width/2 - wall_r, 0, 0); // side wall
  spheres[3].r = wall_r;
  spheres[3].mat = GOLD_SPEC;

  spheres[4].pos = vec3(0, 0, room_width/2 + wall_r); // front wall
  spheres[4].r = wall_r;
  spheres[4].mat = SILVER_SPEC;

  spheres[5].pos = vec3(0, 0, -room_width/2 - wall_r); // back wall
  spheres[5].r = wall_r;
  spheres[5].mat = SILVER_SPEC;

  spheres[6].pos = vec3(0, 2, -8);
  spheres[6].r = 2;
  spheres[6].mat = SILVER_SPEC;

  spheres[7].pos = vec3(0, 3, -1);
  spheres[7].r = 3;
  spheres[7].mat = GOLD_SPEC;
  
  spheres[8].pos = vec3(0, 4, 8);
  spheres[8].r = 4;
  spheres[8].mat = MIRROR;
  
  sphere_count = 9;
}

void main() {
  const uint SPF =20; // sample per frame 
  const uint MAX_DEPTH = 10;
  const float gamma = 2.2;
  
  load_mats();
  
  //mats[2].albedo = vec3(1); // for white light
  //load_scene1();
  
  //mats[2].albedo = vec3(0.5, 0.05, 0.05); // for red light
  //load_scene2();
  
  load_scene3();
  
  vec3 pixel_color = vec3(0);
  uint seed = uint(screen_size.z+1)*init_rand_seed(uint(dot(gl_FragCoord.xz, vec2(gl_FragCoord.y))), uint(dot(gl_FragCoord.zy, vec2(gl_FragCoord.x))));
  for(int s = 0; s < SPF; ++s) {
    pixel_color += calc_sample(MAX_DEPTH, seed);
  }
  pixel_color /= float(SPF);

  vec4 prev_color = imageLoad(out_img, ivec2(gl_FragCoord.xy));
  vec3 last_frame_color = prev_color.xyz * float(screen_size.z);
  pixel_color += last_frame_color;
  pixel_color /= float(screen_size.z+1);
  imageStore(out_img, ivec2(gl_FragCoord.xy), vec4(pixel_color, 1));
  
  pixel_color = ACESFilm(pixel_color);
  pixel_color = LinearToSRGB(pixel_color);  
  frag_color = vec4(pixel_color, 1);
}
