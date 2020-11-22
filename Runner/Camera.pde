public class Camera {
  float yaw = 0;
  float pitch = 0;
  float prevX = screenSize[0]/2;
  float prevY = screenSize[1]/2;
  
  vec3 pos;
  vec3 dir;
  vec3 up;
  
  mat4 view, invView;
  mat4 proj, invProj;
  final float rotSpeed = 0.025f;
  final float moveSpeed = 0.002f;
  
  int shaderProjLoc, shaderViewLoc, invProjLoc, invViewLoc;
  boolean wKey = false, sKey = false, aKey = false, dKey = false, spaceKey = false, shiftKey = false, isActive = true;
  
  public Camera(float posx, float posy, float posz, float dirx, float diry, float dirz) {
    proj = MMath.perspective(MMath.radians(45.0f), (float)screenSize[0] / (float)screenSize[1], 0.1, 2000.0f);
    invProj = MMath.inverse(proj);
    pos = new vec3(posx, posy, posz);
    dir = new vec3(dirx, diry, dirz);
    up = new vec3(0, 1, 0);
    view = MMath.lookAt(pos, dir, up);
    win = (GLWindow)surface.getNative();
  }
  
  public void mouseCallback() {
    if(!isActive) return;
    
    float dx = prevX-mouseX;
    float dy = prevY-mouseY;
    prevX = mouseX;
    prevY = mouseY;
    yaw += dx * rotSpeed;
    pitch += dy * rotSpeed;
    if(pitch > 89.0)
      pitch = 89.0;
    if (pitch < -89.0)
      pitch = -89.0;
    
    dir = MMath.normalize(new vec3(sin(MMath.radians(yaw)) * cos(MMath.radians(pitch)),
                                   sin(MMath.radians(pitch)),
                                   cos(MMath.radians(yaw)) * cos(MMath.radians(pitch))));
    
    prevX = screenSize[0]/2.0; // recenter mouse
    prevY = screenSize[1]/2.0;
    win.warpPointer((int) prevX, (int) prevY); 
  }
  
  public boolean setKbState(final int _keyCode, final char _key, final boolean state) {
    if(!isActive) return state;
    switch(_key) {
    case 'w':
    case 'W':
      return wKey = state; // forward
    case 's':
    case 'S':
      return sKey = state; // backward
    case 'a':
    case 'A':
      return aKey = state; // left
    case 'd':
    case 'D':
      return dKey = state; // right
    case ' ':
      return spaceKey = state; // up
    default:
      switch(_keyCode) {
      case SHIFT:
        return shiftKey = state;
      default:
        return state;
      }
   }
  }
  
  public void updatePos(float dt) {
    if(!isActive) return;
    if (wKey)
      pos.add(MMath.mul(dir, moveSpeed * dt));
    if (sKey)
      pos.add(MMath.mul(dir, moveSpeed * dt * -1));
    if (aKey)
      pos.add(MMath.mul(MMath.normalize(MMath.cross(up, dir)), moveSpeed * dt));
    if (dKey)
      pos.add(MMath.mul(MMath.normalize(MMath.cross(up, dir)), moveSpeed * dt * -1));
    if (spaceKey)
      pos.add(MMath.mul(MMath.normalize(up), moveSpeed * dt));
    if (shiftKey)
      pos.add(MMath.mul(MMath.normalize(up), moveSpeed * dt * -1));
  }
  
  void updateUniforms() {
    mat4 currView = MMath.lookAt(pos, MMath.add(pos, dir), up);
    if(!view.equals(currView)) { // camera view or position changed
      screenSize[2] = 0;
      view.m = currView.m;
      invView = MMath.inverse(view);
      gl.glUniformMatrix4fv(shaderViewLoc, 1, false, view.m, 0);
      gl.glUniformMatrix4fv(invViewLoc, 1, false, invView.m, 0);
    }
  }
}
