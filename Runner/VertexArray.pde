import com.jogamp.opengl.GL4;

public enum BufferType {
  VERTEX,
  INDEX,
}

class VertexArray {
  int id;
  
  void create() {
    int ids[] = new int[1];
    ids[0] = id;
    gl.glCreateVertexArrays(1, ids, 0);
  }
  
  void addBuffer(Buffer buffer, BufferType type, int stride) {
    switch(type) {
    case VERTEX:
      gl.glVertexArrayVertexBuffer(id, 0, buffer.id, 0, stride);
    case INDEX:
      gl.glVertexArrayElementBuffer(id, buffer.id);
    }
  }
  
  void addAttrib(int index, int offset, int count) {
    gl.glEnableVertexArrayAttrib(id, index);
    gl.glVertexArrayAttribFormat(id, index, count, GL.GL_FLOAT, false, offset);
    gl.glVertexArrayAttribBinding(id, index, 0);
  }
  
  void bind(){
    gl.glBindVertexArray(id);
  }
}
