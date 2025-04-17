#define D3_AHB1PERIPH_BASE 0
#define PERIPH_BASE               (0x40000000UL) /*!< Base address of : AHB/APB Peripherals                                                   */
#define D3_APB1PERIPH_BASE       (PERIPH_BASE + 0x18000000UL)
#define RCC_BASE              (D3_AHB1PERIPH_BASE + 0x4400UL)

// translate
//
// pub const PERIPH_BASE = @as(c_ulong, 0x40000000);
//
// pub const D3_APB1PERIPH_BASE = PERIPH_BASE + @as(c_ulong, 0x18000000);
//
// pub const RCC_BASE = D3_AHB1PERIPH_BASE + @as(c_ulong, 0x4400);
