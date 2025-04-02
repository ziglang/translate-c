const __helpers = @This();
// BEGIN_SOURCE
/// "Usual arithmetic conversions" from C11 standard 6.3.1.8
pub fn ArithmeticConversion(comptime A: type, comptime B: type) type {
    if (A == c_longdouble or B == c_longdouble) return c_longdouble;
    if (A == f80 or B == f80) return f80;
    if (A == f64 or B == f64) return f64;
    if (A == f32 or B == f32) return f32;

    const A_Promoted = __helpers.PromotedIntType(A);
    const B_Promoted = __helpers.PromotedIntType(B);
    const std = @import("std");
    comptime {
        std.debug.assert(__helpers.integerRank(A_Promoted) >= __helpers.integerRank(c_int));
        std.debug.assert(__helpers.integerRank(B_Promoted) >= __helpers.integerRank(c_int));
    }

    if (A_Promoted == B_Promoted) return A_Promoted;

    const a_signed = @typeInfo(A_Promoted).int.signedness == .signed;
    const b_signed = @typeInfo(B_Promoted).int.signedness == .signed;

    if (a_signed == b_signed) {
        return if (__helpers.integerRank(A_Promoted) > __helpers.integerRank(B_Promoted)) A_Promoted else B_Promoted;
    }

    const SignedType = if (a_signed) A_Promoted else B_Promoted;
    const UnsignedType = if (!a_signed) A_Promoted else B_Promoted;

    if (__helpers.integerRank(UnsignedType) >= __helpers.integerRank(SignedType)) return UnsignedType;

    if (std.math.maxInt(SignedType) >= std.math.maxInt(UnsignedType)) return SignedType;

    return __helpers.ToUnsigned(SignedType);
}

/// Integer promotion described in C11 6.3.1.1.2
fn PromotedIntType(comptime T: type) type {
    return switch (T) {
        bool, c_short => c_int,
        c_ushort => if (@sizeOf(c_ushort) == @sizeOf(c_int)) c_uint else c_int,
        c_int, c_uint, c_long, c_ulong, c_longlong, c_ulonglong => T,
        else => switch (@typeInfo(T)) {
            .comptime_int => @compileError("Cannot promote `" ++ @typeName(T) ++ "`; a fixed-size number type is required"),
            // promote to c_int if it can represent all values of T
            .int => |int_info| if (int_info.bits < @bitSizeOf(c_int))
                c_int
                // otherwise, restore the original C type
            else if (int_info.bits == @bitSizeOf(c_int))
                if (int_info.signedness == .unsigned) c_uint else c_int
            else if (int_info.bits <= @bitSizeOf(c_long))
                if (int_info.signedness == .unsigned) c_ulong else c_long
            else if (int_info.bits <= @bitSizeOf(c_longlong))
                if (int_info.signedness == .unsigned) c_ulonglong else c_longlong
            else
                @compileError("Cannot promote `" ++ @typeName(T) ++ "`; a C ABI type is required"),
            else => @compileError("Attempted to promote invalid type `" ++ @typeName(T) ++ "`"),
        },
    };
}

/// C11 6.3.1.1.1
fn integerRank(comptime T: type) u8 {
    return switch (T) {
        bool => 0,
        u8, i8 => 1,
        c_short, c_ushort => 2,
        c_int, c_uint => 3,
        c_long, c_ulong => 4,
        c_longlong, c_ulonglong => 5,
        else => @compileError("integer rank not supported for `" ++ @typeName(T) ++ "`"),
    };
}

fn ToUnsigned(comptime T: type) type {
    return switch (T) {
        c_int => c_uint,
        c_long => c_ulong,
        c_longlong => c_ulonglong,
        else => @compileError("Cannot convert `" ++ @typeName(T) ++ "` to unsigned"),
    };
}
