const cast = @import("cast.zig").cast;
// BEGIN_SOURCE
/// A 2-argument function-like macro defined as #define FOO(A, B) (A)(B)
/// could be either: cast B to A, or call A with the value B.
pub fn CAST_OR_CALL(a: anytype, b: anytype) switch (@typeInfo(@TypeOf(a))) {
    .type => a,
    .@"fn" => |fn_info| fn_info.return_type orelse void,
    else => |info| @compileError("Unexpected argument type: " ++ @tagName(info)),
} {
    switch (@typeInfo(@TypeOf(a))) {
        .type => return cast(a, b),
        .@"fn" => return a(b),
        else => unreachable, // return type will be a compile error otherwise
    }
}
