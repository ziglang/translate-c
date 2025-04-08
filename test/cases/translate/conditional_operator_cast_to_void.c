int bar();
void foo() {
    int a;
    a ? a = 2 : bar();
}

// translate
//
// pub extern fn bar(...) c_int;
// pub export fn foo() void {
//     var a: c_int = undefined;
//     _ = &a;
//     if (a != 0) a = 2 else _ = bar();
// }
