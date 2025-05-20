int foo(int bar) {
    extern int arr[];
    if (bar) {
        return *(arr + 2);
    }
    return 0;
}

// translate
//
// pub export fn foo(arg_bar: c_int) c_int {
//     var bar = arg_bar;
//     _ = &bar;
//     const extern_local_arr = struct {
//         const arr: [*c]c_int = @extern([*c]c_int, .{
//             .name = "arr",
//         });
//     };
//     _ = &extern_local_arr;
//     if (bar != 0) {
//         return (extern_local_arr.arr + @as(usize, @bitCast(@as(isize, @intCast(@as(c_int, 2)))))).*;
//     }
//     return 0;
// }