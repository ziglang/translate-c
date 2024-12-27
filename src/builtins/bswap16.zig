pub inline fn __builtin_bswap16(val: u16) u16 {
    return @byteSwap(val);
}
