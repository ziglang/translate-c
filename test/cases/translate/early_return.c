static unsigned long early_return(void) {
	return 8 * 1024 * 1024;
	return 2 * 1024 * 1024;
}

// translate
//
// pub fn early_return() callconv(.c) c_ulong {
//     return @bitCast(@as(c_long, (@as(c_int, 8) * @as(c_int, 1024)) * @as(c_int, 1024)));
// }
