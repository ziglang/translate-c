typedef void Foo;
Foo fun(Foo *a);

// translate
//
// pub const Foo = anyopaque;
//
// pub extern fn fun(a: ?*Foo) void;
