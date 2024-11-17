const char *foo(void) {
    return "bar";
}

// translate
// expect=fail
//
// pub export fn foo() [*c]const u8 {
//     return "bar";
// }
