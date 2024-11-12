void foo() { if(0 && "error message") {} }

// translate
// expect=fail
//
// pub export fn foo() void {
//     if (false and (@intFromPtr("error message") != 0)) {}
// }
