public static class vec3 {
  public float x;
  public float y;
  public float z;
  
  public vec3(float _x, float _y, float _z) {
    x = _x;
    y = _y;
    z = _z;
  }
  
  public void add(vec3 other) {
    x += other.x;
    y += other.y;
    z += other.z;
  }
  
  public String toString() {
    return "vec3(" + x + ", " + y + ", " + z + ")";
  }
}

public static class mat4 {
  // row-major
  public float m[];
  
  public mat4() {
    //defaults to identity matrix
    m = new float[16];
    set(0,0,1);
    set(1,1,1);
    set(2,2,1);
    set(3,3,1);
  }
  
  public void zero() {
    for(int i = 0; i < 16; ++i) {
      m[i] = 0;
    }
  }
  
  public void set(int row, int col, float val) {
    m[row*4+col] = val;
  }
  
  public float get(int row, int col) {
    return m[row*4+col];
  }
}

public static class MMath {
  public static final float PI = 3.141592;
  private MMath() {}
  
  public static vec3 normalize(vec3 vec) {
    float len = sqrt(vec.x*vec.x + vec.y*vec.y + vec.z*vec.z);
    return new vec3(vec.x/len, vec.y/len, vec.z/len);
  }
  
  public static vec3 add(vec3 a, vec3 b) { // no operator overloading in java :(
    return new vec3(a.x+b.x, a.y+b.y, a.z+b.z);
  }
  
  public static vec3 sub(vec3 a, vec3 b) {
    return new vec3(a.x-b.x, a.y-b.y, a.z-b.z);
  }
  
  public static vec3 mul(vec3 a, float scalar) {
    return new vec3(a.x*scalar, a.y*scalar, a.z*scalar);
  }
  
  public static float dot(vec3 a, vec3 b) {
    return a.x*b.x + a.y*b.y + a.z*b.z;
  }
  
  public static vec3 cross(vec3 a, vec3 b) {
    float x = a.y*b.z - a.z*b.y;
    float y = a.z*b.x - a.x*b.z;
    float z = a.x*b.y - a.y*b.x;
    return new vec3(x, y, z);
  }
  
  public static float radians(float deg) {
    return deg * MMath.PI / 180.0f;
  }
   
  public static mat4 perspective(float fov, float ratio, float near, float far) {
    // impl identical to glm's perspective
    // credit:   https://github.com/g-truc/glm/blob/0.9.5/glm/gtc/matrix_transform.inl#L208
    float halfTanFov = tan(fov/2);
    mat4 result = new mat4();
    result.zero();
    result.set(0,0,1 / (ratio * halfTanFov));
    result.set(1,1,1 / halfTanFov);
    result.set(2,2,-(far + near) / (far - near));
    result.set(2,3,-1);
    result.set(3,2,-(2 * far * near) / (far - near));
    return result;
  }
  
  public static mat4 lookAt(vec3 pos, vec3 center, vec3 up) {
    // impl identical to glm's lookAt
    // credit:   https://github.com/g-truc/glm/blob/0.9.5/glm/gtc/matrix_transform.inl#L385
    vec3 f = normalize(sub(center, pos));
    vec3 s = normalize(cross(f, up));
    vec3 u = cross(s, f);
    mat4 result = new mat4();
    
    result.set(0,0,s.x);
    result.set(1,0,s.y);
    result.set(2,0,s.z);
    result.set(0,1,u.x);
    result.set(1,1,u.y);
    result.set(2,1,u.z);
    result.set(0,2, -f.x);
    result.set(1,2, -f.y);
    result.set(2,2, -f.z);
    result.set(3,0, -dot(s, pos));
    result.set(3,1, -dot(u, pos));
    result.set(3,2,dot(f, pos));
    return result;
  }
  
  public static mat4 inverse(mat4 mat) {
    // credit to David Moore, https://cgit.freedesktop.org/mesa/glu/tree/src/libutil/project.c
    float det;
    mat4 result = new mat4();

    result.m[0] =   mat.m[5]*mat.m[10]*mat.m[15] - mat.m[5]*mat.m[11]*mat.m[14] - mat.m[9]*mat.m[6]*mat.m[15]
             + mat.m[9]*mat.m[7]*mat.m[14] + mat.m[13]*mat.m[6]*mat.m[11] - mat.m[13]*mat.m[7]*mat.m[10];
    result.m[4] =  -mat.m[4]*mat.m[10]*mat.m[15] + mat.m[4]*mat.m[11]*mat.m[14] + mat.m[8]*mat.m[6]*mat.m[15]
             - mat.m[8]*mat.m[7]*mat.m[14] - mat.m[12]*mat.m[6]*mat.m[11] + mat.m[12]*mat.m[7]*mat.m[10];
    result.m[8] =   mat.m[4]*mat.m[9]*mat.m[15] - mat.m[4]*mat.m[11]*mat.m[13] - mat.m[8]*mat.m[5]*mat.m[15]
             + mat.m[8]*mat.m[7]*mat.m[13] + mat.m[12]*mat.m[5]*mat.m[11] - mat.m[12]*mat.m[7]*mat.m[9];
    result.m[12] = -mat.m[4]*mat.m[9]*mat.m[14] + mat.m[4]*mat.m[10]*mat.m[13] + mat.m[8]*mat.m[5]*mat.m[14]
             - mat.m[8]*mat.m[6]*mat.m[13] - mat.m[12]*mat.m[5]*mat.m[10] + mat.m[12]*mat.m[6]*mat.m[9];
    result.m[1] =  -mat.m[1]*mat.m[10]*mat.m[15] + mat.m[1]*mat.m[11]*mat.m[14] + mat.m[9]*mat.m[2]*mat.m[15]
             - mat.m[9]*mat.m[3]*mat.m[14] - mat.m[13]*mat.m[2]*mat.m[11] + mat.m[13]*mat.m[3]*mat.m[10];
    result.m[5] =   mat.m[0]*mat.m[10]*mat.m[15] - mat.m[0]*mat.m[11]*mat.m[14] - mat.m[8]*mat.m[2]*mat.m[15]
             + mat.m[8]*mat.m[3]*mat.m[14] + mat.m[12]*mat.m[2]*mat.m[11] - mat.m[12]*mat.m[3]*mat.m[10];
    result.m[9] =  -mat.m[0]*mat.m[9]*mat.m[15] + mat.m[0]*mat.m[11]*mat.m[13] + mat.m[8]*mat.m[1]*mat.m[15]
             - mat.m[8]*mat.m[3]*mat.m[13] - mat.m[12]*mat.m[1]*mat.m[11] + mat.m[12]*mat.m[3]*mat.m[9];
    result.m[13] =  mat.m[0]*mat.m[9]*mat.m[14] - mat.m[0]*mat.m[10]*mat.m[13] - mat.m[8]*mat.m[1]*mat.m[14]
             + mat.m[8]*mat.m[2]*mat.m[13] + mat.m[12]*mat.m[1]*mat.m[10] - mat.m[12]*mat.m[2]*mat.m[9];
    result.m[2] =   mat.m[1]*mat.m[6]*mat.m[15] - mat.m[1]*mat.m[7]*mat.m[14] - mat.m[5]*mat.m[2]*mat.m[15]
             + mat.m[5]*mat.m[3]*mat.m[14] + mat.m[13]*mat.m[2]*mat.m[7] - mat.m[13]*mat.m[3]*mat.m[6];
    result.m[6] =  -mat.m[0]*mat.m[6]*mat.m[15] + mat.m[0]*mat.m[7]*mat.m[14] + mat.m[4]*mat.m[2]*mat.m[15]
             - mat.m[4]*mat.m[3]*mat.m[14] - mat.m[12]*mat.m[2]*mat.m[7] + mat.m[12]*mat.m[3]*mat.m[6];
    result.m[10] =  mat.m[0]*mat.m[5]*mat.m[15] - mat.m[0]*mat.m[7]*mat.m[13] - mat.m[4]*mat.m[1]*mat.m[15]
             + mat.m[4]*mat.m[3]*mat.m[13] + mat.m[12]*mat.m[1]*mat.m[7] - mat.m[12]*mat.m[3]*mat.m[5];
    result.m[14] = -mat.m[0]*mat.m[5]*mat.m[14] + mat.m[0]*mat.m[6]*mat.m[13] + mat.m[4]*mat.m[1]*mat.m[14]
             - mat.m[4]*mat.m[2]*mat.m[13] - mat.m[12]*mat.m[1]*mat.m[6] + mat.m[12]*mat.m[2]*mat.m[5];
    result.m[3] =  -mat.m[1]*mat.m[6]*mat.m[11] + mat.m[1]*mat.m[7]*mat.m[10] + mat.m[5]*mat.m[2]*mat.m[11]
             - mat.m[5]*mat.m[3]*mat.m[10] - mat.m[9]*mat.m[2]*mat.m[7] + mat.m[9]*mat.m[3]*mat.m[6];
    result.m[7] =   mat.m[0]*mat.m[6]*mat.m[11] - mat.m[0]*mat.m[7]*mat.m[10] - mat.m[4]*mat.m[2]*mat.m[11]
             + mat.m[4]*mat.m[3]*mat.m[10] + mat.m[8]*mat.m[2]*mat.m[7] - mat.m[8]*mat.m[3]*mat.m[6];
    result.m[11] = -mat.m[0]*mat.m[5]*mat.m[11] + mat.m[0]*mat.m[7]*mat.m[9] + mat.m[4]*mat.m[1]*mat.m[11]
             - mat.m[4]*mat.m[3]*mat.m[9] - mat.m[8]*mat.m[1]*mat.m[7] + mat.m[8]*mat.m[3]*mat.m[5];
    result.m[15] =  mat.m[0]*mat.m[5]*mat.m[10] - mat.m[0]*mat.m[6]*mat.m[9] - mat.m[4]*mat.m[1]*mat.m[10]
             + mat.m[4]*mat.m[2]*mat.m[9] + mat.m[8]*mat.m[1]*mat.m[6] - mat.m[8]*mat.m[2]*mat.m[5];

    det = mat.m[0]*result.m[0] + mat.m[1]*result.m[4] + mat.m[2]*result.m[8] + mat.m[3]*result.m[12];
    det = 1.0 / det;
    
    if(det == 0) // no inv exists, just crash
      throw new ArithmeticException("Inverse doesn't exist");

    for (int i = 0; i < 16; i++)
        result.m[i] *= det;

    return result;
  }
}
