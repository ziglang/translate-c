#define GUARANTEED_TO_FIT_1 1024
#define GUARANTEED_TO_FIT_2 10241024L
#define GUARANTEED_TO_FIT_3 20482048LU
#define MAY_NEED_PROMOTION_1 10241024
#define MAY_NEED_PROMOTION_2 307230723072L
#define MAY_NEED_PROMOTION_3 819281928192LU
#define MAY_NEED_PROMOTION_HEX 0x80000000
#define MAY_NEED_PROMOTION_OCT 020000000000

// translate
// expect=fail
//
// pub const GUARANTEED_TO_FIT_1 = @as(c_int, 1024);
// pub const GUARANTEED_TO_FIT_2 = @as(c_long, 10241024);
// pub const GUARANTEED_TO_FIT_3 = @as(c_ulong, 20482048);
// pub const MAY_NEED_PROMOTION_1 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 10241024, .decimal);
// pub const MAY_NEED_PROMOTION_2 = @import("std").zig.c_translation.promoteIntLiteral(c_long, 307230723072, .decimal);
// pub const MAY_NEED_PROMOTION_3 = @import("std").zig.c_translation.promoteIntLiteral(c_ulong, 819281928192, .decimal);
// pub const MAY_NEED_PROMOTION_HEX = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x80000000, .hex);
// pub const MAY_NEED_PROMOTION_OCT = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0o20000000000, .octal);
