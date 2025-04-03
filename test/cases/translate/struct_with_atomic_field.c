struct arcan_shmif_cont {
        struct arcan_shmif_page* addr;
};
struct arcan_shmif_page {
        volatile _Atomic int abufused[12];
};

// translate
//
// warning: struct demoted to opaque type - unable to translate type of field abufused
// pub const struct_arcan_shmif_page = opaque {};
// pub const struct_arcan_shmif_cont = extern struct {
//     addr: ?*struct_arcan_shmif_page = null,
// };
