pub inline fn __builtin_bswap64(val: u64) u64 {
    return @byteSwap(val);
}
