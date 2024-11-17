#define CURLAUTH_BASIC_BUT_USHORT ((unsigned short) 1)
#define CURLAUTH_BASIC ((unsigned long) 1)
#define CURLAUTH_BASIC_BUT_ULONGLONG ((unsigned long long) 1)

// translate
// expect=fail
//
// pub const CURLAUTH_BASIC_BUT_USHORT = @import("std").zig.c_translation.cast(c_ushort, @as(c_int, 1));
// pub const CURLAUTH_BASIC = @import("std").zig.c_translation.cast(c_ulong, @as(c_int, 1));
// pub const CURLAUTH_BASIC_BUT_ULONGLONG = @import("std").zig.c_translation.cast(c_ulonglong, @as(c_int, 1));
