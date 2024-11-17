#define ACCESS array[2]
int array[100] = {};
int foo(int index) {
    return array[index];
}

// translate
// expect=fail
//
// pub export var array: [100]c_int = [1]c_int{0} ** 100;
// pub export fn foo(arg_index: c_int) c_int {
//     var index = arg_index;
//     _ = &index;
//     return array[@as(c_uint, @intCast(index))];
// }
//
// pub inline fn ACCESS() @TypeOf(array[@as(usize, @intCast(@as(c_int, 2)))]) {
//     return array[@as(usize, @intCast(@as(c_int, 2)))];
// }
