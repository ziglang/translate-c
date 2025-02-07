const char *foo(void) {
    return "bar";
}

// translate
//
// pub export fn foo() [*c]const u8 {
//     return "bar";
// }
