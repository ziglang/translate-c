int foo(void) {
    return ({
        int a = 1;
        a;
        a;
    });
}

// translate
// expect=fail
//
// pub export fn foo() c_int {
//     return blk: {
//         var a: c_int = 1;
//         _ = &a;
//         _ = &a;
//         break :blk a;
//     };
// }
