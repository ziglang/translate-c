typedef void Foo;
Foo fun(Foo *a);

// translate
// expect=fail
//
// pub const Foo = anyopaque;
//
// pub extern fn fun(a: ?*Foo) void;
