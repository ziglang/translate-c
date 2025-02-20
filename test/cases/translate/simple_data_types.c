#include <stdint.h>
int foo(char a, unsigned char b, signed char c);
int foo(char a, unsigned char b, signed char c); // test a duplicate prototype
void bar(uint8_t a, uint16_t b, uint32_t c, uint64_t d);
void baz(int8_t a, int16_t b, int32_t c, int64_t d);

// translate
//
// pub extern fn foo(a: u8, b: u8, c: i8) c_int;
// pub extern fn bar(a: u8, b: u16, c: u32, d: u64) void;
// pub extern fn baz(a: i8, b: i16, c: i32, d: i64) void;
