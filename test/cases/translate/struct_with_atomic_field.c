struct arcan_shmif_cont {
        struct arcan_shmif_page* addr;
};
struct arcan_shmif_page {
        volatile _Atomic int abufused[12];
};

// translate
// expect=fail
//
// source.h:4:8: warning: struct demoted to opaque type - unable to translate type of field abufused
// pub const struct_arcan_shmif_page = opaque {};
// pub const struct_arcan_shmif_cont = extern struct {
//     addr: ?*struct_arcan_shmif_page = @import("std").mem.zeroes(?*struct_arcan_shmif_page),
// };
