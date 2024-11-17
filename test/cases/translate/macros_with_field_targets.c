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
// expect=fail
//
// pub const GLbitfield = c_uint;
// pub const PFNGLCLEARPROC = ?*const fn (GLbitfield) callconv(.c) void;
// pub const OpenGLProc = ?*const fn () callconv(.c) void;
// const struct_unnamed_1 = extern struct {
//     Clear: PFNGLCLEARPROC = @import("std").mem.zeroes(PFNGLCLEARPROC),
// };
// pub const union_OpenGLProcs = extern union {
//     ptr: [1]OpenGLProc,
//     gl: struct_unnamed_1,
// };
// pub extern var glProcs: union_OpenGLProcs;
//
// pub const glClearPFN = PFNGLCLEARPROC;
//
// pub inline fn glClearUnion(arg_2: GLbitfield) void {
//     return glProcs.gl.Clear.?(arg_2);
// }
//
// pub const OpenGLProcs = union_OpenGLProcs;
