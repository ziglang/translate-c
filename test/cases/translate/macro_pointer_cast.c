#define NRF_GPIO_BASE 0
typedef struct { int dummy; } NRF_GPIO_Type;
#define NRF_GPIO ((NRF_GPIO_Type *) NRF_GPIO_BASE)

// translate
//
// pub const NRF_GPIO = __helpers.cast([*c]NRF_GPIO_Type, NRF_GPIO_BASE);
