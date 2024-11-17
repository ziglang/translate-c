typedef char* yes;
void foo(void) {
    yes a;
    if (a) 2;
}

// translate
// expect=fail
//
// pub const yes = [*c]u8;
// pub export fn foo() void {
//     var a: yes = undefined;
//     _ = &a;
//     if (a != null) {
//         _ = @as(c_int, 2);
//     }
// }
