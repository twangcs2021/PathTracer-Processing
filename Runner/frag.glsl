#version 400 core

out vec4 frag_color;

uniform vec2 screen_size;
uniform mat4 inv_cam_proj;
uniform mat4 inv_cam_view;
uniform mat4 cam_proj;
uniform mat4 cam_view; 


#define PI 3.1415926
#define EPS 1e-3
#define T_MAX 1e6

struct Material {
  vec3 albedo;
  vec3 emmitence;
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

uint wang_hash(inout uint seed) {
    seed = uint(seed ^ uint(61)) ^ uint(seed >> uint(16));
    seed *= uint(9);
    seed = seed ^ (seed >> 4);
    seed *= uint(0x27d4eb2d);
    seed = seed ^ (seed >> 15);
    return seed;
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

#define NUM_SPHERES 3
#define NUM_MATERIALS 2

Sphere spheres[NUM_SPHERES];
Material mats[NUM_MATERIALS];

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
  for(int i = 0; i < NUM_SPHERES; ++i) {
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
  vec2 uv = pixel_center / screen_size;
  uv = uv * 2.0 - 1.0;
  vec4 origin = inv_cam_view * vec4(0,0,0,1);
  vec4 target = inv_cam_proj * vec4(uv.x, uv.y, focal_len, 1);
  vec4 dir = inv_cam_view * vec4(normalize(target.xyz), 0);
  Ray ray;
  ray.dir = dir.xyz;
  ray.origin = origin.xyz;
  return ray;
}

vec3 calc_sample(uint max_bounces, inout uint rng_state) {
  vec3 accumulator = vec3(0);
  vec3 mask = vec3(1);
  
  Ray ray = gen_ray(rng_state);
  uint id;
  for(int b = 0; b < max_bounces; ++b) {
    float t = intersect_scene(id, ray);
    if(t < EPS) break;
    
    Material mat = mats[spheres[id].mat];
    
    vec3 emmisive = mat.emmitence*mat.albedo;
    mask *= mat.albedo;
    accumulator += mask * emmisive;
    
    vec3 inter_p = ray.origin + ray.dir*t;
    vec3 normal = normalize(inter_p - spheres[id].pos);
    ray.origin = inter_p;
    ray.dir = normalize(normal + rand_vec(rng_state));
  }
  return accumulator;
}

void main() {
  const uint SPP = 100;
  const uint MAX_DEPTH = 1000000;
  const float gamma = 2.2;
  
  { // init scene
    mats[0].albedo = vec3(1);
    mats[0].emmitence = vec3(0);
    
    mats[1].albedo = vec3(1);
    mats[1].emmitence = vec3(1);
    
    const float room_height = 7.0f;
    const float room_width = 7.0f;
    
    spheres[0].pos = vec3(0, 1, 0); //subject
    spheres[0].r = 1;
    spheres[0].mat = 1;
    
    spheres[1].pos = vec3(0, -100, 0); // bottom floor
    spheres[1].r = 100;
    spheres[1].mat = 0;
    
    spheres[2].pos = vec3(0, room_height+100, 0); // top ceiling
    spheres[2].r = 100;
    spheres[2].mat = 0;
    
    //spheres[3].pos = vec3(room_width/2 + 100.0, 0, 0); // side wall
    //spheres[3].r = 100;
    //spheres[3].mat = 0;
    
    //spheres[4].pos = vec3(-room_width/2 - 100.0, 0, 0); // side wall
    //spheres[4].r = 100;
    //spheres[4].mat = 0;
    
    //spheres[5].pos = vec3(0, 0, room_width/2 + 100.0); // front wall
    //spheres[5].r = 100;
    //spheres[5].mat = 0;
    
    //spheres[6].pos = vec3(0, 0, -room_width/2 - 100.0); // back wall
    //spheres[6].r = 100;
    //spheres[6].mat = 0;
  }
  
  vec3 pixel_color = vec3(0);
  uint seed = uint(dot(gl_FragCoord.xy, vec2(gl_FragCoord.z)));
  for(int s = 0; s < SPP; ++s) {
    pixel_color += calc_sample(MAX_DEPTH, seed);
  }
  pixel_color /= float(SPP);
  frag_color = vec4(pow(pixel_color, vec3(2.2)), 1.0);
  frag_color = vec4(pixel_color, 1.0);
  //debug noise
  //frag_color = vec4(vec3(rand(gl_FragCoord.xy)), 1);
}
