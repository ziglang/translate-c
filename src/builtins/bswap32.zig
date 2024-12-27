pub inline fn __builtin_bswap32(val: u32) u32 {
    return @byteSwap(val);
}
