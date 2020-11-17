#version 420 core

#extension GL_EXT_shader_image_load_store : require

layout(location = 0) in vec3 pos;

uniform mat4 cam_proj;
uniform mat4 cam_view;

void main() {
  gl_Position = vec4(pos.xyz, 1.0);
}
