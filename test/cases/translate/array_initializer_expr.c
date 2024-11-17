static void foo(void){
    char arr[10] ={1};
    char *arr1[10] ={0};
}

// translate
// expect=fail
//
// pub fn foo() callconv(.c) void {
//     var arr: [10]u8 = [1]u8{
//         1,
//     } ++ [1]u8{0} ** 9;
//     _ = &arr;
//     var arr1: [10][*c]u8 = [1][*c]u8{
//         null,
//     } ++ [1][*c]u8{null} ** 9;
//     _ = &arr1;
// }
