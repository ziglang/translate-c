#define _IO_ERR_SEEN 0
#define __ferror_unlocked_body(_fp) (((_fp)->_flags & _IO_ERR_SEEN) != 0)

// translate
// expect=fail
//
// pub inline fn __ferror_unlocked_body(_fp: anytype) @TypeOf((_fp.*._flags & _IO_ERR_SEEN) != @as(c_int, 0)) {
//     _ = &_fp;
//     return (_fp.*._flags & _IO_ERR_SEEN) != @as(c_int, 0);
// }
