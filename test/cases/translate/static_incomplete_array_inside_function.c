void foo(void) {
    static const char v2[] = "2.2.2";
}

// translate
// expect=fail
//
// pub export fn foo() void {
//     const v2 = struct {
//         const static: [5:0]u8 = "2.2.2".*;
//     };
//     _ = &v2;
// }
