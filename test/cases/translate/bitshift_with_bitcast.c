unsigned int bit31() {
    return 1u << (31);
}

// translate
//
// pub export fn bit31() c_uint {
//     return @as(c_uint, 1) << @intCast(@as(c_uint, @bitCast(@as(c_int, @as(c_int, 31)))));
// }
