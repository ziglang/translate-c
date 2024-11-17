void foo(void) {
    int a;
    1;
    "hey";
    1 + 1;
    1 - 1;
    a = 1;
}

// translate
// expect=fail
//
// pub export fn foo() void {
//     var a: c_int = undefined;
//     _ = &a;
//     _ = @as(c_int, 1);
//     _ = "hey";
//     _ = @as(c_int, 1) + @as(c_int, 1);
//     _ = @as(c_int, 1) - @as(c_int, 1);
//     a = 1;
// }
