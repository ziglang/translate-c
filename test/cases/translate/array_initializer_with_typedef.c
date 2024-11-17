typedef unsigned char uuid_t[16];
static const uuid_t UUID_NULL __attribute__ ((unused)) = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};

// translate
// expect=fail
//
// pub const uuid_t = [16]u8;
// pub const UUID_NULL: uuid_t = [16]u8{
//     0,
//     0,
//     0,
//     0,
//     0,
//     0,
//     0,
//     0,
//     0,
//     0,
//     0,
//     0,
//     0,
//     0,
//     0,
//     0,
// };
