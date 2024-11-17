typedef void lws_callback_function(void);
struct Foo {
    void (*func)(void);
    lws_callback_function *callback_http;
};

// translate
// expect=fail
//
// pub const lws_callback_function = fn () callconv(.c) void;
// pub const struct_Foo = extern struct {
//     func: ?*const fn () callconv(.c) void = @import("std").mem.zeroes(?*const fn () callconv(.c) void),
//     callback_http: ?*const lws_callback_function = @import("std").mem.zeroes(?*const lws_callback_function),
// };
