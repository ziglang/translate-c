void foo(void) {
    __func__;
    __FUNCTION__;
    __PRETTY_FUNCTION__;
}

// translate
// expect=fail
//
// pub export fn foo() void {
//     _ = "foo";
//     _ = "foo";
//     _ = "void foo(void)";
// }
