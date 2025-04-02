/// Given a type and value, cast the value to the type as c would.
pub fn cast(comptime DestType: type, target: anytype) DestType {
    // this function should behave like transCCast in translate-c, except it's for macros
    const SourceType = @TypeOf(target);
    switch (@typeInfo(DestType)) {
        .@"fn" => return castToPtr(*const DestType, SourceType, target),
        .pointer => return castToPtr(DestType, SourceType, target),
        .optional => |dest_opt| {
            if (@typeInfo(dest_opt.child) == .pointer) {
                return castToPtr(DestType, SourceType, target);
            } else if (@typeInfo(dest_opt.child) == .@"fn") {
                return castToPtr(?*const dest_opt.child, SourceType, target);
            }
        },
        .int => {
            switch (@typeInfo(SourceType)) {
                .pointer => {
                    return castInt(DestType, @intFromPtr(target));
                },
                .optional => |opt| {
                    if (@typeInfo(opt.child) == .pointer) {
                        return castInt(DestType, @intFromPtr(target));
                    }
                },
                .int => {
                    return castInt(DestType, target);
                },
                .@"fn" => {
                    return castInt(DestType, @intFromPtr(&target));
                },
                .bool => {
                    return @intFromBool(target);
                },
                else => {},
            }
        },
        .float => {
            switch (@typeInfo(SourceType)) {
                .int => return @as(DestType, @floatFromInt(target)),
                .float => return @as(DestType, @floatCast(target)),
                .bool => return @as(DestType, @floatFromInt(@intFromBool(target))),
                else => {},
            }
        },
        .@"union" => |info| {
            inline for (info.fields) |field| {
                if (field.type == SourceType) return @unionInit(DestType, field.name, target);
            }
            @compileError("cast to union type '" ++ @typeName(DestType) ++ "' from type '" ++ @typeName(SourceType) ++ "' which is not present in union");
        },
        .bool => return cast(usize, target) != 0,
        else => {},
    }
    return @as(DestType, target);
}

fn castInt(comptime DestType: type, target: anytype) DestType {
    const dest = @typeInfo(DestType).int;
    const source = @typeInfo(@TypeOf(target)).int;

    const Int = @Type(.{ .int = .{ .bits = dest.bits, .signedness = source.signedness } });

    if (dest.bits < source.bits)
        return @as(DestType, @bitCast(@as(Int, @truncate(target))))
    else
        return @as(DestType, @bitCast(@as(Int, target)));
}

fn castPtr(comptime DestType: type, target: anytype) DestType {
    return @constCast(@volatileCast(@alignCast(@ptrCast(target))));
}

fn castToPtr(comptime DestType: type, comptime SourceType: type, target: anytype) DestType {
    switch (@typeInfo(SourceType)) {
        .int => {
            return @as(DestType, @ptrFromInt(castInt(usize, target)));
        },
        .comptime_int => {
            if (target < 0)
                return @as(DestType, @ptrFromInt(@as(usize, @bitCast(@as(isize, @intCast(target))))))
            else
                return @as(DestType, @ptrFromInt(@as(usize, @intCast(target))));
        },
        .pointer => {
            return castPtr(DestType, target);
        },
        .@"fn" => {
            return castPtr(DestType, &target);
        },
        .optional => |target_opt| {
            if (@typeInfo(target_opt.child) == .pointer) {
                return castPtr(DestType, target);
            }
        },
        else => {},
    }
    return @as(DestType, target);
}
