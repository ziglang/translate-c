static void foo(void){
    char arr[10] ={1};
    char *arr1[10] ={0};
    int arr2[5] = {0, [1] = 1, [3] = 3, 4};
    int arr3[6] = {0, [0] = 10, [2] = 2, [0] = 100, 4, 5};
    int arr4[7] = {[1] = 1, [2] = 2, [5] = 5};
    int arr5[0] = {};
    int arr6[9] = {};
}

// translate
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
//     var arr2: [5]c_int = [2]c_int{
//         0,
//         1,
//     } ++ [1]c_int{0} ** 1 ++ [2]c_int{
//         3,
//         4,
//     };
//     _ = &arr2;
//     var arr3: [6]c_int = [3]c_int{
//         100,
//         4,
//         5,
//     } ++ [1]c_int{0} ** 3;
//     _ = &arr3;
//     var arr4: [7]c_int = [1]c_int{0} ** 1 ++ [2]c_int{
//         1,
//         2,
//     } ++ [1]c_int{0} ** 2 ++ [1]c_int{
//         5,
//     } ++ [1]c_int{0} ** 1;
//     _ = &arr4;
//     var arr5: [0]c_int = .{};
//     _ = &arr5;
//     var arr6: [9]c_int = [1]c_int{0} ** 9;
//     _ = &arr6;
// }
