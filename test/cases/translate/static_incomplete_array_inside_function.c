void foo(void) {
    static const char v2[] = "2.2.2";
}

// translate
//
// pub export fn foo() void {
//     const static_local_v2 = struct {
//         var v2: [5:0]u8 = "2.2.2".*;
//     };
//     _ = &static_local_v2;
// }
