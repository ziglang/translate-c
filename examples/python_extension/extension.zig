// Python extension written in Zig using translate-c
const python = @import("python"); // This is the translated Python.h
const std = @import("std");

// Python method definitions
const methods = [_]python.PyMethodDef{
    .{
        .ml_name = "get_greeting",
        .ml_meth = py_get_greeting,
        .ml_flags = python.METH_NOARGS,
        .ml_doc = "Get a greeting from Zig",
    },
    .{
        .ml_name = "add_numbers",
        .ml_meth = py_add_numbers,
        .ml_flags = python.METH_VARARGS,
        .ml_doc = "Add two integers together",
    },
    .{ .ml_name = null, .ml_meth = null, .ml_flags = 0, .ml_doc = null },
};

// Python wrapper functions
fn py_get_greeting(self: [*c]python.PyObject, args: [*c]python.PyObject) callconv(.c) [*c]python.PyObject {
    _ = self;
    _ = args;
    const greeting = "Hello from Zig-based Python extension!";
    return python.PyUnicode_FromString(greeting);
}

fn py_add_numbers(self: [*c]python.PyObject, args: [*c]python.PyObject) callconv(.c) [*c]python.PyObject {
    _ = self;

    var a: c_int = undefined;
    var b: c_int = undefined;

    if (python.PyArg_ParseTuple(args, "ii", &a, &b) == 0) {
        return null;
    }

    const result = a + b;
    return python.PyLong_FromLong(result);
}

// Module definition
var module_def = python.PyModuleDef{
    .m_base = .{ .ob_base = std.mem.zeroes(python.PyObject) },
    .m_name = "zig_ext",
    .m_doc = "Python extension written in Zig using translate-c",
    .m_size = -1,
    .m_methods = @constCast(&methods),
    .m_slots = null,
    .m_traverse = null,
    .m_clear = null,
    .m_free = null,
};

// Module initialization function - this is called when Python imports the module
export fn PyInit_zig_ext() *python.PyObject {
    return python.PyModule_Create(&module_def);
}
