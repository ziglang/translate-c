void foo() {
    int c = 1;
    c ?: foo();
}

// translate
//
// pub export fn foo() void {
//     var c: c_int = 1;
//     _ = &c;
//     if (c != 0) foo();
// }
