enum Foo {
    FooA,
    FooB,
    FooC,
};
typedef int SomeTypedef;
int and_or_non_bool(int a, float b, void *c) {
    enum Foo d = FooA;
    int e = (a && b);
    int f = (b && c);
    int g = (a && c);
    int h = (a || b);
    int i = (b || c);
    int j = (a || c);
    int k = (a || (int)d);
    int l = ((int)d && b);
    int m = (c || (unsigned int)d);
    SomeTypedef td = 44;
    int o = (td || b);
    int p = (c && td);
    return ((((((((((e + f) + g) + h) + i) + j) + k) + l) + m) + o) + p);
}

// translate
// target=native-linux
//
// pub const FooA: c_int = 0;
// pub const FooB: c_int = 1;
// pub const FooC: c_int = 2;
// pub const enum_Foo = c_uint;
// pub const SomeTypedef = c_int;
// pub export fn and_or_non_bool(arg_a: c_int, arg_b: f32, arg_c: ?*anyopaque) c_int {
//     var a = arg_a;
//     _ = &a;
//     var b = arg_b;
//     _ = &b;
//     var c = arg_c;
//     _ = &c;
//     var d: enum_Foo = FooA;
//     _ = &d;
//     var e: c_int = @intFromBool((@as(f32, @floatFromInt(a)) != 0) and (b != 0));
//     _ = &e;
//     var f: c_int = @intFromBool((b != 0) and (c != null));
//     _ = &f;
//     var g: c_int = @intFromBool((a != 0) and (c != null));
//     _ = &g;
//     var h: c_int = @intFromBool((@as(f32, @floatFromInt(a)) != 0) or (b != 0));
//     _ = &h;
//     var i: c_int = @intFromBool((b != 0) or (c != null));
//     _ = &i;
//     var j: c_int = @intFromBool((a != 0) or (c != null));
//     _ = &j;
//     var k: c_int = @intFromBool((a != 0) or (@as(c_int, @bitCast(d)) != 0));
//     _ = &k;
//     var l: c_int = @intFromBool((@as(f32, @floatFromInt(@as(c_int, @bitCast(d)))) != 0) and (b != 0));
//     _ = &l;
//     var m: c_int = @intFromBool((c != null) or (d != 0));
//     _ = &m;
//     var td: SomeTypedef = 44;
//     _ = &td;
//     var o: c_int = @intFromBool((@as(f32, @floatFromInt(td)) != 0) or (b != 0));
//     _ = &o;
//     var p: c_int = @intFromBool((c != null) and (td != 0));
//     _ = &p;
//     return (((((((((e + f) + g) + h) + i) + j) + k) + l) + m) + o) + p;
// }
//
// pub const Foo = enum_Foo;
