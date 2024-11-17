#define NRF_GPIO_BASE 0
typedef struct { int dummy; } NRF_GPIO_Type;
#define NRF_GPIO ((NRF_GPIO_Type *) NRF_GPIO_BASE)

// translate
// expect=fail
//
// pub const NRF_GPIO = @import("std").zig.c_translation.cast([*c]NRF_GPIO_Type, NRF_GPIO_BASE);
