struct foo {
    __attribute__((aligned(4))) short bar;
};

// translate
// 
// pub const struct_foo = extern struct {
//     bar: c_short align(4) = 0,
// };
