const std = @import("std");

const ast = @import("ast.zig");

/// All builtins need to have a source so that macros can reference them
/// but for some it is possible to directly call an equivalent Zig builtin
/// which is preferrable.
pub const Builtin = struct {
    tag: ?ast.Node.Tag = null,
    source: []const u8,
};

pub const map = std.StaticStringMap(Builtin).initComptime([_]struct { []const u8, Builtin }{
    .{ "__builtin_abs", .{ .source = @embedFile("builtins/abs.zig") } },
    .{ "__builtin_assume", .{ .source = @embedFile("builtins/assume.zig") } },
    .{ "__builtin_bswap16", .{ .source = @embedFile("builtins/bswap16.zig"), .tag = .byte_swap } },
    .{ "__builtin_bswap32", .{ .source = @embedFile("builtins/bswap32.zig"), .tag = .byte_swap } },
    .{ "__builtin_bswap64", .{ .source = @embedFile("builtins/bswap64.zig"), .tag = .byte_swap } },
    .{ "__builtin_ceilf", .{ .source = @embedFile("builtins/ceilf.zig"), .tag = .ceil } },
    .{ "__builtin_ceil", .{ .source = @embedFile("builtins/ceil.zig"), .tag = .ceil } },
    .{ "__builtin_clz", .{ .source = @embedFile("builtins/clz.zig") } },
    .{ "__builtin_constant_p", .{ .source = @embedFile("builtins/constant_p.zig") } },
    .{ "__builtin_cosf", .{ .source = @embedFile("builtins/cosf.zig"), .tag = .cos } },
    .{ "__builtin_cos", .{ .source = @embedFile("builtins/cos.zig"), .tag = .cos } },
    .{ "__builtin_ctz", .{ .source = @embedFile("builtins/ctz.zig") } },
    .{ "__builtin_exp2f", .{ .source = @embedFile("builtins/exp2f.zig"), .tag = .exp2 } },
    .{ "__builtin_exp2", .{ .source = @embedFile("builtins/exp2.zig"), .tag = .exp2 } },
    .{ "__builtin_expf", .{ .source = @embedFile("builtins/expf.zig"), .tag = .exp } },
    .{ "__builtin_exp", .{ .source = @embedFile("builtins/exp.zig"), .tag = .exp } },
    .{ "__builtin_fabsf", .{ .source = @embedFile("builtins/fabsf.zig"), .tag = .abs } },
    .{ "__builtin_fabs", .{ .source = @embedFile("builtins/fabs.zig"), .tag = .abs } },
    .{ "__builtin_floorf", .{ .source = @embedFile("builtins/floorf.zig"), .tag = .floor } },
    .{ "__builtin_floor", .{ .source = @embedFile("builtins/floor.zig"), .tag = .floor } },
    .{ "__builtin_huge_valf", .{ .source = @embedFile("builtins/huge_valf.zig") } },
    .{ "__builtin_inff", .{ .source = @embedFile("builtins/inff.zig") } },
    .{ "__builtin_isinf_sign", .{ .source = @embedFile("builtins/isinf_sign.zig") } },
    .{ "__builtin_isinf", .{ .source = @embedFile("builtins/isinf.zig") } },
    .{ "__builtin_isnan", .{ .source = @embedFile("builtins/isnan.zig") } },
    .{ "__builtin_labs", .{ .source = @embedFile("builtins/labs.zig") } },
    .{ "__builtin_llabs", .{ .source = @embedFile("builtins/llabs.zig") } },
    .{ "__builtin_log10f", .{ .source = @embedFile("builtins/log10f.zig"), .tag = .log10 } },
    .{ "__builtin_log10", .{ .source = @embedFile("builtins/log10.zig"), .tag = .log10 } },
    .{ "__builtin_log2f", .{ .source = @embedFile("builtins/log2f.zig"), .tag = .log2 } },
    .{ "__builtin_log2", .{ .source = @embedFile("builtins/log2.zig"), .tag = .log2 } },
    .{ "__builtin_logf", .{ .source = @embedFile("builtins/logf.zig"), .tag = .log } },
    .{ "__builtin_log", .{ .source = @embedFile("builtins/log.zig"), .tag = .log } },
    .{ "__builtin___memcpy_chk", .{ .source = @embedFile("builtins/memcpy_chk.zig") } },
    .{ "__builtin_memcpy", .{ .source = @embedFile("builtins/memcpy.zig") } },
    .{ "__builtin___memset_chk", .{ .source = @embedFile("builtins/memset_chk.zig") } },
    .{ "__builtin_memset", .{ .source = @embedFile("builtins/memset.zig") } },
    .{ "__builtin_mul_overflow", .{ .source = @embedFile("builtins/mul_overflow.zig") } },
    .{ "__builtin_nanf", .{ .source = @embedFile("builtins/nanf.zig") } },
    .{ "__builtin_object_size", .{ .source = @embedFile("builtins/object_size.zig") } },
    .{ "__builtin_popcount", .{ .source = @embedFile("builtins/popcount.zig") } },
    .{ "__builtin_roundf", .{ .source = @embedFile("builtins/roundf.zig"), .tag = .round } },
    .{ "__builtin_round", .{ .source = @embedFile("builtins/round.zig"), .tag = .round } },
    .{ "__builtin_signbitf", .{ .source = @embedFile("builtins/signbitf.zig") } },
    .{ "__builtin_signbit", .{ .source = @embedFile("builtins/signbit.zig") } },
    .{ "__builtin_sinf", .{ .source = @embedFile("builtins/sinf.zig"), .tag = .sin } },
    .{ "__builtin_sin", .{ .source = @embedFile("builtins/sin.zig"), .tag = .sin } },
    .{ "__builtin_sqrtf", .{ .source = @embedFile("builtins/sqrtf.zig"), .tag = .sqrt } },
    .{ "__builtin_sqrt", .{ .source = @embedFile("builtins/sqrt.zig"), .tag = .sqrt } },
    .{ "__builtin_strcmp", .{ .source = @embedFile("builtins/strcmp.zig") } },
    .{ "__builtin_strlen", .{ .source = @embedFile("builtins/strlen.zig") } },
    .{ "__builtin_truncf", .{ .source = @embedFile("builtins/truncf.zig"), .tag = .trunc } },
    .{ "__builtin_trunc", .{ .source = @embedFile("builtins/trunc.zig"), .tag = .trunc } },
    .{ "__builtin_unreachable", .{ .source = @embedFile("builtins/unreachable.zig"), .tag = .@"unreachable" } },
    .{ "__has_builtin", .{ .source = @embedFile("builtins/has_builtin.zig") } },

    // __builtin_alloca_with_align is not currently implemented.
    // It is used in a run and a translate test to ensure that non-implemented
    // builtins are correctly demoted. If you implement __builtin_alloca_with_align,
    // please update the tests to use a different non-implemented builtin.
});
