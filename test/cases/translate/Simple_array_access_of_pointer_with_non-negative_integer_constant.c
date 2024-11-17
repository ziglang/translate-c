void foo(int *p) {
    p[0];
    p[1];
}

// translate
// expect=fail
//
// _ = p[@as(c_uint, @intCast(@as(c_int, 0)))];
//
// _ = p[@as(c_uint, @intCast(@as(c_int, 1)))];
