typedef enum {
    a,
    b,
    c,
} d;
enum {
    e,
    f = 4,
    g,
} h = e;
struct Baz {
    enum {
        i,
        j,
        k,
    } l;
    d m;
};
enum i {
    n,
    o,
    p,
};

// translate
// target=native-linux
//
// pub const a: c_int = 0;
// pub const b: c_int = 1;
// pub const c: c_int = 2;
// pub const d = c_uint;
// pub const e: c_int = 0;
// pub const f: c_int = 4;
// pub const g: c_int = 5;
// const enum_unnamed_1 = c_uint;
// pub export var h: enum_unnamed_1 = e;
// pub const i: c_int = 0;
// pub const j: c_int = 1;
// pub const k: c_int = 2;
// const enum_unnamed_2 = c_uint;
// pub const struct_Baz = extern struct {
//     l: enum_unnamed_2 = @import("std").mem.zeroes(enum_unnamed_2),
//     m: d = @import("std").mem.zeroes(d),
// };
// pub const n: c_int = 0;
// pub const o: c_int = 1;
// pub const p: c_int = 2;
// pub const enum_i = c_uint;
//
// pub const Baz = struct_Baz;
