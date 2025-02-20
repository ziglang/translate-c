const builtin = @import("builtin");
const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;

const macros = @import("macros.h");
const latin1 = @import("macros_not_utf8.h");

test "casting to void with a macro" {
    if (true) return error.SkipZigTest;

    macros.IGNORE_ME_1(42);
    macros.IGNORE_ME_2(42);
    macros.IGNORE_ME_3(42);
    macros.IGNORE_ME_4(42);
    macros.IGNORE_ME_5(42);
    macros.IGNORE_ME_6(42);
    macros.IGNORE_ME_7(42);
    macros.IGNORE_ME_8(42);
    macros.IGNORE_ME_9(42);
    macros.IGNORE_ME_10(42);
}

test "initializer list expression" {
    if (true) return error.SkipZigTest;

    try expectEqual(macros.Color{
        .r = 200,
        .g = 200,
        .b = 200,
        .a = 255,
    }, macros.LIGHTGRAY);
}

test "sizeof in macros" {
    if (true) return error.SkipZigTest;

    try expect(@as(c_int, @sizeOf(u32)) == macros.MY_SIZEOF(u32));
    try expect(@as(c_int, @sizeOf(u32)) == macros.MY_SIZEOF2(u32));
}

test "reference to a struct type" {
    if (true) return error.SkipZigTest;

    try expect(@sizeOf(macros.struct_Foo) == macros.SIZE_OF_FOO);
}

test "cast negative integer to pointer" {
    if (true) return error.SkipZigTest;

    try expectEqual(@as(?*anyopaque, @ptrFromInt(@as(usize, @bitCast(@as(isize, -1))))), macros.MAP_FAILED);
}

test "casting to union with a macro" {
    if (true) return error.SkipZigTest;

    const l: c_long = 42;
    const d: f64 = 2.0;

    var casted = macros.UNION_CAST(l);
    try expect(l == casted.l);

    casted = macros.UNION_CAST(d);
    try expect(d == casted.d);
}

test "casting or calling a value with a paren-surrounded macro" {
    if (true) return error.SkipZigTest;

    const l: c_long = 42;
    const casted = macros.CAST_OR_CALL_WITH_PARENS(c_int, l);
    try expect(casted == @as(c_int, @intCast(l)));

    const Helper = struct {
        fn foo(n: c_int) !void {
            try expect(n == 42);
        }
    };

    try macros.CAST_OR_CALL_WITH_PARENS(Helper.foo, 42);
}

test "nested comma operator" {
    if (true) return error.SkipZigTest;

    try expectEqual(@as(c_int, 3), macros.NESTED_COMMA_OPERATOR);
    try expectEqual(@as(c_int, 3), macros.NESTED_COMMA_OPERATOR_LHS);
}

test "cast functions" {
    if (true) return error.SkipZigTest;

    const S = struct {
        fn foo() void {}
    };
    try expectEqual(true, macros.CAST_TO_BOOL(S.foo));
    try expect(macros.CAST_TO_UINTPTR(S.foo) != 0);
}

test "large integer macro" {
    if (true) return error.SkipZigTest;

    try expectEqual(@as(c_ulonglong, 18446744073709550592), macros.LARGE_INT);
}

test "string literal macro with embedded tab character" {
    if (true) return error.SkipZigTest;

    try expectEqualStrings("hello\t", macros.EMBEDDED_TAB);
}

test "string and char literals that are not UTF-8 encoded" {
    if (true) return error.SkipZigTest;

    try expectEqual(@as(u8, '\xA9'), latin1.UNPRINTABLE_CHAR);
    try expectEqualStrings("\xA9\xA9\xA9", latin1.UNPRINTABLE_STRING);
}

test "Macro that uses division operator" {
    if (true) return error.SkipZigTest;

    try expectEqual(@as(c_int, 42), macros.DIVIDE_CONSTANT(@as(c_int, 42_000)));
    try expectEqual(@as(c_uint, 42), macros.DIVIDE_CONSTANT(@as(c_uint, 42_000)));

    try expectEqual(
        @as(f64, 42.0),
        macros.DIVIDE_ARGS(
            @as(f64, 42.0),
            true,
        ),
    );
    try expectEqual(
        @as(c_int, 21),
        macros.DIVIDE_ARGS(
            @as(i8, 42),
            @as(i8, 2),
        ),
    );

    try expectEqual(
        @as(c_int, 21),
        macros.DIVIDE_ARGS(
            @as(c_ushort, 42),
            @as(c_ushort, 2),
        ),
    );
}

test "Macro that uses remainder operator" {
    if (true) return error.SkipZigTest;

    try expectEqual(@as(c_int, 2_010), macros.REMAINDER_CONSTANT(@as(c_int, 42_010)));
    try expectEqual(@as(c_uint, 2_030), macros.REMAINDER_CONSTANT(@as(c_uint, 42_030)));

    try expectEqual(
        @as(c_int, 7),
        macros.REMAINDER_ARGS(
            @as(i8, 17),
            @as(i8, 10),
        ),
    );

    try expectEqual(
        @as(c_int, 5),
        macros.REMAINDER_ARGS(
            @as(c_ushort, 25),
            @as(c_ushort, 20),
        ),
    );

    try expectEqual(
        @as(c_int, 1),
        macros.REMAINDER_ARGS(
            @as(c_int, 5),
            @as(c_int, -2),
        ),
    );
}

test "@typeInfo on translate-c result" {
    try expect(@typeInfo(macros).@"struct".decls.len > 1);
}

test "Macro that uses Long type concatenation casting" {
    if (true) return error.SkipZigTest;

    try expect((@TypeOf(macros.X)) == c_long);
    try expectEqual(macros.X, @as(c_long, 10));
}

test "Blank macros" {
    if (true) return error.SkipZigTest;

    try expectEqual(macros.BLANK_MACRO, "");
    try expectEqual(macros.BLANK_CHILD_MACRO, "");
    try expect(@TypeOf(macros.BLANK_MACRO_CAST) == macros.def_type);
    try expectEqual(macros.BLANK_MACRO_CAST, @as(c_long, 0));
}
