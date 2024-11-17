#include <stdint.h>
char zero[0] = "abc";
uint32_t zero_w[0] = U"💯💯💯";
char empty_incomplete[] = "";
uint32_t empty_incomplete_w[] = U"";
char empty_constant[100] = "";
uint32_t empty_constant_w[100] = U"";
char incomplete[] = "abc";
uint32_t incomplete_w[] = U"💯💯💯";
char truncated[1] = "abc";
uint32_t truncated_w[1] = U"💯💯💯";
char extend[5] = "a";
uint32_t extend_w[5] = U"💯";
char no_null[3] = "abc";
uint32_t no_null_w[3] = U"💯💯💯";

// translate
// expect=fail
//
// pub export var zero: [0]u8 = [0]u8{};
// pub export var zero_w: [0]u32 = [0]u32{};
// pub export var empty_incomplete: [1]u8 = [1]u8{0} ** 1;
// pub export var empty_incomplete_w: [1]u32 = [1]u32{0} ** 1;
// pub export var empty_constant: [100]u8 = [1]u8{0} ** 100;
// pub export var empty_constant_w: [100]u32 = [1]u32{0} ** 100;
// pub export var incomplete: [3:0]u8 = "abc".*;
// pub export var incomplete_w: [3:0]u32 = [3:0]u32{
//     '\u{1f4af}',
//     '\u{1f4af}',
//     '\u{1f4af}',
// };
// pub export var truncated: [1]u8 = "abc"[0..1].*;
// pub export var truncated_w: [1]u32 = [1]u32{
//     '\u{1f4af}',
// };
// pub export var extend: [5]u8 = "a"[0..1].* ++ [1]u8{0} ** 4;
// pub export var extend_w: [5]u32 = [1]u32{
//     '\u{1f4af}',
// } ++ [1]u32{0} ** 4;
// pub export var no_null: [3]u8 = "abc".*;
// pub export var no_null_w: [3]u32 = [3]u32{
//     '\u{1f4af}',
//     '\u{1f4af}',
//     '\u{1f4af}',
// };
