typedef unsigned int GLbitfield;
typedef void (*PFNGLCLEARPROC) (GLbitfield mask);
typedef void(*OpenGLProc)(void);
union OpenGLProcs {
    OpenGLProc ptr[1];
    struct {
        PFNGLCLEARPROC Clear;
    } gl;
};
extern union OpenGLProcs glProcs;
#define glClearUnion glProcs.gl.Clear
#define glClearPFN PFNGLCLEARPROC

// translate
//
// pub const GLbitfield = c_uint;
// pub const PFNGLCLEARPROC = ?*const fn (mask: GLbitfield) callconv(.c) void;
// pub const OpenGLProc = ?*const fn () callconv(.c) void;
// const struct_unnamed_1 = extern struct {
//     Clear: PFNGLCLEARPROC = null,
// };
// pub const union_OpenGLProcs = extern union {
//     ptr: [1]OpenGLProc,
//     gl: struct_unnamed_1,
// };
// pub extern var glProcs: union_OpenGLProcs;
//
// pub const glClearPFN = PFNGLCLEARPROC;
//
// pub inline fn glClearUnion(mask: GLbitfield) void {
//     return glProcs.gl.Clear.?(mask);
// }
//
// pub const OpenGLProcs = union_OpenGLProcs;
