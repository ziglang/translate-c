struct Foo {
    int a;
};
extern int foo(const struct Foo *);
extern int bar(struct Foo *);

// translate
//
// pub const struct_Foo = extern struct {
//     a: c_int = 0,
//     pub const foo = __root.foo;
//     pub const bar = __root.bar;
// };
// pub extern fn foo([*c]const struct_Foo) c_int;
// pub extern fn bar([*c]struct_Foo) c_int;
