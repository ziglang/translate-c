void foo(void) {
    int a;
    1;
    "hey";
    1 + 1;
    1 - 1;
    a = 1;
}

// translate
//
// pub export fn foo() void {
//     var a: c_int = undefined;
//     _ = &a;
//     _ = 1;
//     _ = "hey";
//     _ = 1 + 1;
//     _ = 1 - 1;
//     a = 1;
// }
