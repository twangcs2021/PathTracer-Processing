import java.nio.*;
import com.jogamp.opengl.GL4;

public class Buffer {
  int id;
  
  Buffer() {}
  
  void create() {
    int ids[] = new int[1];
    gl.glCreateBuffers(1, ids, 0);
    id = ids[0];
  }
  
  void delete() {
    int ids[] = new int[1];
    ids[0] = id;
    gl.glDeleteBuffers(1, ids, 0); 
  }
  
  void init(long size, java.nio.Buffer data, int target, int usage) {
    bind(target);
    gl.glBufferData(target, size, data, usage);
    unbind(target);
  }
  
  void update(long offset, long size, java.nio.Buffer data) { // not supported by PJOGL
    gl.glNamedBufferSubData(id, offset, size, data);
  }
  
  void bind(int target) {
    gl.glBindBuffer(target, id);
  }
  
  void unbind(int target){
    gl.glBindBuffer(target, 0);
  }
}
