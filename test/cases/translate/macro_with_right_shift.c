#define FLASH_SIZE         0x200000UL          /* 2 MB   */
#define FLASH_BANK_SIZE    (FLASH_SIZE >> 1)   /* 1 MB   */

// translate
// expect=fail
//
// pub const FLASH_SIZE = @as(c_ulong, 0x200000);
//
// pub const FLASH_BANK_SIZE = FLASH_SIZE >> @as(c_int, 1);
