typedef struct {
    int foo;
    char* bar;
} Foo;

int Foo_bar(Foo foo);
int baz(Foo *foo);
int libsomething_quux(Foo *foo);
int foo1_bar(Foo *foo);
int foo2_bar(Foo *foo);

typedef union {
    int foo;
    float numb;
} UFoo;

int UFoo_bar(UFoo ufoo);
int ubaz(UFoo *ufoo);
int libsomething_union_quux(UFoo *ufoo);

typedef struct opa_foo OpaFoo;

int opa_foo_init(OpaFoo *foo);
int opa_foo1_bar(OpaFoo foo);
int opa_foo2_bar(OpaFoo *foo);

typedef struct foo_quux FooQuux;

int foo_quux_bar1(FooQuux *foo);
int foo_quux_bar2_(FooQuux *foo);

// translate
//
// pub const Foo = extern struct {
//     foo: c_int = 0,
//     bar: [*c]u8 = null,
//     pub const Foo_bar = __root.Foo_bar;
//     pub const baz = __root.baz;
//     pub const libsomething_quux = __root.libsomething_quux;
//     pub const foo1_bar = __root.foo1_bar;
//     pub const foo2_bar = __root.foo2_bar;
//     pub const quux = __root.libsomething_quux;
// };
// pub extern fn Foo_bar(foo: Foo) c_int;
// pub extern fn baz(foo: [*c]Foo) c_int;
// pub extern fn libsomething_quux(foo: [*c]Foo) c_int;
// pub extern fn foo1_bar(foo: [*c]Foo) c_int;
// pub extern fn foo2_bar(foo: [*c]Foo) c_int;
// pub const UFoo = extern union {
//     foo: c_int,
//     numb: f32,
//     pub const UFoo_bar = __root.UFoo_bar;
//     pub const ubaz = __root.ubaz;
//     pub const libsomething_union_quux = __root.libsomething_union_quux;
//     pub const bar = __root.UFoo_bar;
//     pub const quux = __root.libsomething_union_quux;
// };
// pub extern fn UFoo_bar(ufoo: UFoo) c_int;
// pub extern fn ubaz(ufoo: [*c]UFoo) c_int;
// pub extern fn libsomething_union_quux(ufoo: [*c]UFoo) c_int;
// pub const struct_opa_foo = opaque {
//     pub const opa_foo_init = __root.opa_foo_init;
//     pub const opa_foo1_bar = __root.opa_foo1_bar;
//     pub const opa_foo2_bar = __root.opa_foo2_bar;
//     pub const init = __root.opa_foo_init;
//     pub const bar = __root.opa_foo1_bar;
// };
// pub const OpaFoo = struct_opa_foo;
// pub extern fn opa_foo_init(foo: ?*OpaFoo) c_int;
// pub extern fn opa_foo1_bar(foo: OpaFoo) c_int;
// pub extern fn opa_foo2_bar(foo: ?*OpaFoo) c_int;
// pub const struct_foo_quux = opaque {
//     pub const foo_quux_bar1 = __root.foo_quux_bar1;
//     pub const foo_quux_bar2_ = __root.foo_quux_bar2_;
//     pub const bar1 = __root.foo_quux_bar1;
//     pub const bar2_ = __root.foo_quux_bar2_;
// };
// pub const FooQuux = struct_foo_quux;
// pub extern fn foo_quux_bar1(foo: ?*FooQuux) c_int;
// pub extern fn foo_quux_bar2_(foo: ?*FooQuux) c_int;
