typedef void lws_callback_function(void);
struct Foo {
    void (*func)(void);
    lws_callback_function *callback_http;
};

// translate
//
// pub const lws_callback_function = fn () callconv(.c) void;
// pub const struct_Foo = extern struct {
//     func: ?*const fn () callconv(.c) void = null,
//     callback_http: ?*const lws_callback_function = null,
// };
