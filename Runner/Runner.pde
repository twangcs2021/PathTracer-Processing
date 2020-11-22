import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.FloatBuffer;

import com.jogamp.opengl.GL;
import com.jogamp.opengl.GL4;
import com.jogamp.opengl.GLProfile;
import com.jogamp.newt.opengl.GLWindow;

Camera cam;

float screenSize[] = {1920, 1080, 0}; // last element acts as a frameCount
PShader shader;

int screenSizeLoc;
float quadVerts[] = {
  -1.0f, -1.0f, 0.0f, 
  1.0f, -1.0f, 0.0f, 
  1.0f, 1.0f, 0.0f, 
  1.0f, 1.0f, 0.0f, 
  -1.0f, 1.0f, 0.0f, 
  -1.0f, -1.0f, 0.0f, 
};

VertexArray vao = new VertexArray();
Buffer vbo = new Buffer();
FloatBuffer quadBuffer;
PJOGL pgl;
GL4 gl;
GLWindow win;
void settings() {
  size(int(screenSize[0]), int(screenSize[1]), P3D);
  PJOGL.profile = 4; // need 4.x for dsa
}

FloatBuffer allocateDirectFloatBuffer(int n) {
  return ByteBuffer.allocateDirect(n * Float.BYTES).order(ByteOrder.nativeOrder()).asFloatBuffer();
}

void keyPressed() {
  if(key == 'q') {
    cam.isActive = !cam.isActive;
    if(!cam.isActive) {
      win.setPointerVisible(true);
      win.confinePointer(false);
      cam.wKey = false;
      cam.sKey = false; 
      cam.aKey = false;
      cam.dKey = false;
      cam.spaceKey = false;
      cam.shiftKey = false;
    } else {
      win.setPointerVisible(false);
      win.confinePointer(true);
      win.warpPointer((int)screenSize[0]/2, (int)screenSize[1]/2);
      cam.prevX = screenSize[0]/2;
      cam.prevY = screenSize[1]/2;
    }
  }
  
  cam.setKbState(keyCode, key, true);
}

void keyReleased() {
  cam.setKbState(keyCode, key, false);
}

int tex;
void setup() {
  frameRate(120); // cap to 60fps
  
  shader = loadShader("frag.glsl", "vert.glsl");
  quadBuffer = allocateDirectFloatBuffer(quadVerts.length);
  quadBuffer.rewind();
  quadBuffer.put(quadVerts);
  quadBuffer.rewind();
  win = (GLWindow)surface.getNative();
    win.confinePointer(true);
    win.setPointerVisible(false);
    win.warpPointer((int)screenSize[0]/2, (int)screenSize[1]/2);
  
    cam = new Camera(0, 0, -4, 0, 0, 1);
    cam.prevX = mouseX;
    cam.prevY = mouseY;
  
    pgl = (PJOGL)beginPGL();
    gl = pgl.gl.getGL4();
  
  vao.create();
  vbo.create();
  vao.addAttrib(0, 0, 3);
  vao.addBuffer(vbo, BufferType.VERTEX, Float.BYTES*3);
  vbo.init(quadVerts.length*Float.BYTES, quadBuffer, GL.GL_ARRAY_BUFFER, GL.GL_DYNAMIC_DRAW);
  shader.bind();
  
  screenSizeLoc = gl.glGetUniformLocation(shader.glProgram,     "screen_size");
  cam.shaderProjLoc = gl.glGetUniformLocation(shader.glProgram, "cam_proj");
  cam.shaderViewLoc = gl.glGetUniformLocation(shader.glProgram, "cam_view");
  cam.invProjLoc = gl.glGetUniformLocation(shader.glProgram,    "inv_cam_proj");
  cam.invViewLoc = gl.glGetUniformLocation(shader.glProgram,    "inv_cam_view");
  int outImgLoc = gl.glGetUniformLocation(shader.glProgram,    "out_img");
  gl.glUniform3fv(screenSizeLoc, 1, screenSize, 0);
  gl.glUniformMatrix4fv(cam.shaderProjLoc, 1, false, cam.proj.m, 0);
  gl.glUniformMatrix4fv(cam.invProjLoc, 1, false, cam.invProj.m, 0);
  
  
  int texs[]= new int[1];
  gl.glCreateTextures(GL.GL_TEXTURE_2D, 1, texs, 0);
  tex = texs[0];
  gl.glTextureStorage2D(tex, 1, GL.GL_RGBA32F, (int)screenSize[0], (int)screenSize[1]);
  
  gl.glUniform1i(outImgLoc, 0);
  
  endPGL();
}

long prev = 0;

// this one screws up my framebuffers
void draw() {
  cam.mouseCallback();
  double dt = (-prev + (prev = frameRateLastNanos))/1e6d;
  cam.updatePos((float) dt);
  cam.updateUniforms();
  gl.glUniform3fv(screenSizeLoc, 1, screenSize, 0);
  background(0);
  shader.bind();
  gl.glBindTextureUnit(0, tex);
  gl.glBindImageTexture(0, tex, 0, false, 0, GL4.GL_READ_WRITE, GL.GL_RGBA32F);
  vao.bind();
  vbo.bind(GL.GL_ARRAY_BUFFER);
  gl.glDrawArrays(GL.GL_TRIANGLES, 0, quadVerts.length);
  surface.setTitle("FPS: " + frameRate);
  if(screenSize[2] < 1e6) ++screenSize[2];
}
