const std = @import("std");
const math = std.math;
const mem = std.mem;
const assert = std.debug.assert;

const aro = @import("aro");
const CToken = aro.Tokenizer.Token;

const ast = @import("ast.zig");
const ZigNode = ast.Node;
const ZigTag = ZigNode.Tag;
const Scope = @import("Scope.zig");
const Translator = @import("Translator.zig");

const Error = Translator.Error;
pub const ParseError = Error || error{ParseError};

const MacroTranslator = @This();

t: *Translator,
macro: aro.Preprocessor.Macro,
name: []const u8,

tokens: []const CToken,
source: []const u8,
i: usize = 0,
/// If an object macro references a global var it needs to be converted into
/// an inline function.
refs_var_decl: bool = false,

fn peek(mt: *MacroTranslator) ?CToken.Id {
    if (mt.i >= mt.tokens.len) return null;
    return mt.tokens[mt.i + 1].id;
}

fn next(mt: *MacroTranslator) ?CToken.Id {
    if (mt.i >= mt.tokens.len) return null;
    mt.i += 1;
    return mt.tokens[mt.i].id;
}

fn skip(mt: *MacroTranslator, expected_id: CToken.Id) ParseError!void {
    const next_id = mt.next().?;
    if (next_id != expected_id and !(expected_id == .identifier and next_id == .extended_identifier)) {
        try mt.fail(
            "unable to translate C expr: expected '{s}' instead got '{s}'",
            .{ expected_id.symbol(), next_id.symbol() },
        );
        return error.ParseError;
    }
}

fn fail(mt: *MacroTranslator, comptime fmt: []const u8, args: anytype) !void {
    return mt.t.failDeclExtra(mt.macro.loc, mt.name, fmt, args);
}

fn tokSlice(mt: *const MacroTranslator) []const u8 {
    const tok = mt.tokens[mt.i];
    return mt.source[tok.start..tok.end];
}

pub fn transFnMacro(mt: *MacroTranslator) ParseError!void {
    var block_scope = try Scope.Block.init(mt.t, &mt.t.global_scope.base, false);
    defer block_scope.deinit();
    const scope = &block_scope.base;

    try mt.skip(.l_paren);

    var fn_params = std.ArrayList(ast.Payload.Param).init(mt.t.gpa);
    defer fn_params.deinit();

    while (true) {
        if (!mt.peek().?.isMacroIdentifier()) break;

        _ = mt.next();

        const mangled_name = try block_scope.makeMangledName(mt.tokSlice());
        try fn_params.append(.{
            .is_noalias = false,
            .name = mangled_name,
            .type = ZigTag.@"anytype".init(),
        });
        try block_scope.discardVariable(mangled_name);
        if (mt.peek().? != .comma) break;
        _ = mt.next();
    }

    try mt.skip(.r_paren);

    const expr = try mt.parseCExpr(scope);
    const last = mt.next().?;
    if (last != .eof and last != .nl)
        return mt.fail("unable to translate C expr: unexpected token '{s}'", .{last.symbol()});

    const typeof_arg = if (expr.castTag(.block)) |some| blk: {
        const stmts = some.data.stmts;
        const blk_last = stmts[stmts.len - 1];
        const br = blk_last.castTag(.break_val).?;
        break :blk br.data.val;
    } else expr;

    const return_type = ret: {
        if (typeof_arg.castTag(.helper_call)) |some| {
            if (std.mem.eql(u8, some.data.name, "cast")) {
                break :ret some.data.args[0];
            }
        }
        if (typeof_arg.castTag(.std_mem_zeroinit)) |some| break :ret some.data.lhs;
        if (typeof_arg.castTag(.std_mem_zeroes)) |some| break :ret some.data;
        break :ret try ZigTag.typeof.create(mt.t.arena, typeof_arg);
    };
    
    const return_expr = try ZigTag.@"return".create(mt.t.arena, expr);
    try block_scope.statements.append(mt.t.gpa, return_expr);

    const fn_decl = try ZigTag.pub_inline_fn.create(mt.t.arena, .{
        .name = mt.name,
        .params = try mt.t.arena.dupe(ast.Payload.Param, fn_params.items),
        .return_type = return_type,
        .body = try block_scope.complete(),
    });
    try mt.t.addTopLevelDecl(mt.name, fn_decl);
}

pub fn transMacro(mt: *MacroTranslator) ParseError!void {
    const scope = &mt.t.global_scope.base;

    // Check if the macro only uses other blank macros.
    while (true) {
        switch (mt.peek().?) {
            .identifier, .extended_identifier => {
                const tok = mt.tokens[mt.i + 1];
                const slice = mt.source[tok.start..tok.end];
                if (mt.t.global_scope.blank_macros.contains(slice)) {
                    mt.i += 1;
                    continue;
                }
            },
            .eof, .nl => {
                try mt.t.global_scope.blank_macros.put(mt.t.gpa, mt.name, {});
                const init_node = try ZigTag.string_literal.create(mt.t.arena, "\"\"");
                const var_decl = try ZigTag.pub_var_simple.create(mt.t.arena, .{ .name = mt.name, .init = init_node });
                try mt.t.addTopLevelDecl(mt.name, var_decl);
                return;
            },
            else => {},
        }
        break;
    }

    const init_node = try mt.parseCExpr(scope);
    const last = mt.next().?;
    if (last != .eof and last != .nl)
        return mt.fail("unable to translate C expr: unexpected token '{s}'", .{last.symbol()});

    const node = node: {
        const var_decl = try ZigTag.pub_var_simple.create(mt.t.arena, .{ .name = mt.name, .init = init_node });

        if (mt.t.getFnProto(var_decl)) |proto_node| {
            // If a macro aliases a global variable which is a function pointer, we conclude that
            // the macro is intended to represent a function that assumes the function pointer
            // variable is non-null and calls it.
            break :node try mt.createMacroFn(mt.name, var_decl, proto_node);
        } else if (mt.refs_var_decl) {
            const return_type = try ZigTag.typeof.create(mt.t.arena, init_node);
            const return_expr = try ZigTag.@"return".create(mt.t.arena, init_node);
            const block = try ZigTag.block_single.create(mt.t.arena, return_expr);

            const loc_str = try mt.t.locStr(mt.macro.loc);
            const value = try std.fmt.allocPrint(mt.t.arena, "\n// {s}: warning: macro '{s}' contains a runtime value, translated to function", .{ loc_str, mt.name });
            try scope.appendNode(try ZigTag.warning.create(mt.t.arena, value));

            break :node try ZigTag.pub_inline_fn.create(mt.t.arena, .{
                .name = mt.name,
                .params = &.{},
                .return_type = return_type,
                .body = block,
            });
        }

        break :node var_decl;
    };

    try mt.t.addTopLevelDecl(mt.name, node);
}

fn createMacroFn(mt: *MacroTranslator, name: []const u8, ref: ZigNode, proto_alias: *ast.Payload.Func) !ZigNode {
    var fn_params = std.ArrayList(ast.Payload.Param).init(mt.t.gpa);
    defer fn_params.deinit();

    for (proto_alias.data.params) |param| {
        const param_name = param.name orelse
            try std.fmt.allocPrint(mt.t.arena, "arg_{d}", .{mt.t.getMangle()});

        try fn_params.append(.{
            .name = param_name,
            .type = param.type,
            .is_noalias = param.is_noalias,
        });
    }

    const init = if (ref.castTag(.var_decl)) |v|
        v.data.init.?
    else if (ref.castTag(.var_simple) orelse ref.castTag(.pub_var_simple)) |v|
        v.data.init
    else
        unreachable;

    const unwrap_expr = try ZigTag.unwrap.create(mt.t.arena, init);
    const args = try mt.t.arena.alloc(ZigNode, fn_params.items.len);
    for (fn_params.items, 0..) |param, i| {
        args[i] = try ZigTag.identifier.create(mt.t.arena, param.name.?);
    }
    const call_expr = try ZigTag.call.create(mt.t.arena, .{
        .lhs = unwrap_expr,
        .args = args,
    });
    const return_expr = try ZigTag.@"return".create(mt.t.arena, call_expr);
    const block = try ZigTag.block_single.create(mt.t.arena, return_expr);

    return ZigTag.pub_inline_fn.create(mt.t.arena, .{
        .name = name,
        .params = try mt.t.arena.dupe(ast.Payload.Param, fn_params.items),
        .return_type = proto_alias.data.return_type,
        .body = block,
    });
}

fn parseCExpr(mt: *MacroTranslator, scope: *Scope) ParseError!ZigNode {
    // TODO parseCAssignExpr here
    var block_scope = try Scope.Block.init(mt.t, scope, true);
    defer block_scope.deinit();

    const node = try mt.parseCCondExpr(&block_scope.base);
    if (mt.next().? != .comma) {
        mt.i -= 1;
        return node;
    }

    var last = node;
    while (true) {
        // suppress result
        const ignore = try ZigTag.discard.create(mt.t.arena, .{ .should_skip = false, .value = last });
        try block_scope.statements.append(mt.t.gpa, ignore);

        last = try mt.parseCCondExpr(&block_scope.base);
        if (mt.next().? != .comma) {
            mt.i -= 1;
            break;
        }
    }

    const break_node = try ZigTag.break_val.create(mt.t.arena, .{
        .label = block_scope.label,
        .val = last,
    });
    try block_scope.statements.append(mt.t.gpa, break_node);
    return try block_scope.complete();
}

fn parseCNumLit(mt: *MacroTranslator) ParseError!ZigNode {
    const lit_bytes = mt.tokSlice();
    var bytes = try std.ArrayListUnmanaged(u8).initCapacity(mt.t.arena, lit_bytes.len + 3);

    const prefix = aro.Tree.Token.NumberPrefix.fromString(lit_bytes);
    switch (prefix) {
        .binary => bytes.appendSliceAssumeCapacity("0b"),
        .octal => bytes.appendSliceAssumeCapacity("0o"),
        .hex => bytes.appendSliceAssumeCapacity("0x"),
        .decimal => {},
    }

    const after_prefix = lit_bytes[prefix.stringLen()..];
    const after_int = for (after_prefix, 0..) |c, i| switch (c) {
        '.' => {
            if (i == 0) {
                bytes.appendAssumeCapacity('0');
            }
            break after_prefix[i..];
        },
        'e', 'E' => {
            if (prefix != .hex) break after_prefix[i..];
            bytes.appendAssumeCapacity(c);
        },
        'p', 'P' => break after_prefix[i..],
        '0'...'9', 'a'...'d', 'A'...'D', 'f', 'F' => {
            if (!prefix.digitAllowed(c)) break after_prefix[i..];
            bytes.appendAssumeCapacity(c);
        },
        '\'' => {
            bytes.appendAssumeCapacity('_');
        },
        else => break after_prefix[i..],
    } else "";

    const after_frac = frac: {
        if (after_int.len == 0 or after_int[0] != '.') break :frac after_int;
        bytes.appendAssumeCapacity('.');
        for (after_int[1..], 1..) |c, i| {
            if (c == '\'') {
                bytes.appendAssumeCapacity('_');
                continue;
            }
            if (!prefix.digitAllowed(c)) break :frac after_int[i..];
            bytes.appendAssumeCapacity(c);
        }
        break :frac "";
    };

    const suffix_str = exponent: {
        if (after_frac.len == 0) break :exponent after_frac;
        switch (after_frac[0]) {
            'e', 'E' => {},
            'p', 'P' => if (prefix != .hex) break :exponent after_frac,
            else => break :exponent after_frac,
        }
        bytes.appendAssumeCapacity(after_frac[0]);
        for (after_frac[1..], 1..) |c, i| switch (c) {
            '+', '-', '0'...'9' => {
                bytes.appendAssumeCapacity(c);
            },
            '\'' => {
                bytes.appendAssumeCapacity('_');
            },
            else => break :exponent after_frac[i..],
        };
        break :exponent "";
    };

    const is_float = after_int.len != suffix_str.len;
    const suffix = aro.Tree.Token.NumberSuffix.fromString(suffix_str, if (is_float) .float else .int) orelse {
        try mt.fail("invalid number suffix: '{s}'", .{suffix_str});
        return error.ParseError;
    };
    if (suffix.isImaginary()) {
        try mt.fail("TODO: imaginary literals", .{});
        return error.ParseError;
    }
    if (suffix.isBitInt()) {
        try mt.fail("TODO: _BitInt literals", .{});
        return error.ParseError;
    }

    if (is_float) {
        const type_node = try ZigTag.type.create(mt.t.arena, switch (suffix) {
            .F16 => "f16",
            .F => "f32",
            .None => "f64",
            .L => "c_longdouble",
            .W => "f80",
            .Q, .F128 => "f128",
            else => unreachable,
        });
        const rhs = try ZigTag.float_literal.create(mt.t.arena, bytes.items);
        return ZigTag.as.create(mt.t.arena, .{ .lhs = type_node, .rhs = rhs });
    } else {
        const type_node = try ZigTag.type.create(mt.t.arena, switch (suffix) {
            .None => "c_int",
            .U => "c_uint",
            .L => "c_long",
            .UL => "c_ulong",
            .LL => "c_longlong",
            .ULL => "c_ulonglong",
            else => unreachable,
        });
        const value = std.fmt.parseInt(i128, bytes.items, 0) catch math.maxInt(i128);

        // make the output less noisy by skipping promoteIntLiteral where
        // it's guaranteed to not be required because of C standard type constraints
        const guaranteed_to_fit = switch (suffix) {
            .None => math.cast(i16, value) != null,
            .U => math.cast(u16, value) != null,
            .L => math.cast(i32, value) != null,
            .UL => math.cast(u32, value) != null,
            .LL => math.cast(i64, value) != null,
            .ULL => math.cast(u64, value) != null,
            else => unreachable,
        };

        const literal_node = try ZigTag.integer_literal.create(mt.t.arena, bytes.items);
        if (guaranteed_to_fit) {
            return ZigTag.as.create(mt.t.arena, .{ .lhs = type_node, .rhs = literal_node });
        } else {
            return mt.t.createHelperCallNode(.promoteIntLiteral, &.{ type_node, literal_node, try ZigTag.enum_literal.create(mt.t.arena, @tagName(prefix)) });
        }
    }
}

fn zigifyEscapeSequences(mt: *MacroTranslator) ![]const u8 {
    var source = mt.tokSlice();
    for (source, 0..) |c, i| {
        if (c == '\"' or c == '\'') {
            source = source[i..];
            break;
        }
    }
    for (source) |c| {
        if (c == '\\' or c == '\t') {
            break;
        }
    } else return source;
    var bytes = try mt.t.arena.alloc(u8, source.len * 2);
    var state: enum {
        start,
        escape,
        hex,
        octal,
    } = .start;
    var i: usize = 0;
    var count: u8 = 0;
    var num: u8 = 0;
    for (source) |c| {
        switch (state) {
            .escape => {
                switch (c) {
                    'n', 'r', 't', '\\', '\'', '\"' => {
                        bytes[i] = c;
                    },
                    '0'...'7' => {
                        count += 1;
                        num += c - '0';
                        state = .octal;
                        bytes[i] = 'x';
                    },
                    'x' => {
                        state = .hex;
                        bytes[i] = 'x';
                    },
                    'a' => {
                        bytes[i] = 'x';
                        i += 1;
                        bytes[i] = '0';
                        i += 1;
                        bytes[i] = '7';
                    },
                    'b' => {
                        bytes[i] = 'x';
                        i += 1;
                        bytes[i] = '0';
                        i += 1;
                        bytes[i] = '8';
                    },
                    'f' => {
                        bytes[i] = 'x';
                        i += 1;
                        bytes[i] = '0';
                        i += 1;
                        bytes[i] = 'C';
                    },
                    'v' => {
                        bytes[i] = 'x';
                        i += 1;
                        bytes[i] = '0';
                        i += 1;
                        bytes[i] = 'B';
                    },
                    '?' => {
                        i -= 1;
                        bytes[i] = '?';
                    },
                    'u', 'U' => {
                        try mt.fail("macro tokenizing failed: TODO unicode escape sequences", .{});
                        return error.ParseError;
                    },
                    else => {
                        try mt.fail("macro tokenizing failed: unknown escape sequence", .{});
                        return error.ParseError;
                    },
                }
                i += 1;
                if (state == .escape)
                    state = .start;
            },
            .start => {
                if (c == '\t') {
                    bytes[i] = '\\';
                    i += 1;
                    bytes[i] = 't';
                    i += 1;
                    continue;
                }
                if (c == '\\') {
                    state = .escape;
                }
                bytes[i] = c;
                i += 1;
            },
            .hex => {
                switch (c) {
                    '0'...'9' => {
                        num = std.math.mul(u8, num, 16) catch {
                            try mt.fail("macro tokenizing failed: hex literal overflowed", .{});
                            return error.ParseError;
                        };
                        num += c - '0';
                    },
                    'a'...'f' => {
                        num = std.math.mul(u8, num, 16) catch {
                            try mt.fail("macro tokenizing failed: hex literal overflowed", .{});
                            return error.ParseError;
                        };
                        num += c - 'a' + 10;
                    },
                    'A'...'F' => {
                        num = std.math.mul(u8, num, 16) catch {
                            try mt.fail("macro tokenizing failed: hex literal overflowed", .{});
                            return error.ParseError;
                        };
                        num += c - 'A' + 10;
                    },
                    else => {
                        i += std.fmt.formatIntBuf(bytes[i..], num, 16, .lower, std.fmt.FormatOptions{ .fill = '0', .width = 2 });
                        num = 0;
                        if (c == '\\')
                            state = .escape
                        else
                            state = .start;
                        bytes[i] = c;
                        i += 1;
                    },
                }
            },
            .octal => {
                const accept_digit = switch (c) {
                    // The maximum length of a octal literal is 3 digits
                    '0'...'7' => count < 3,
                    else => false,
                };

                if (accept_digit) {
                    count += 1;
                    num = std.math.mul(u8, num, 8) catch {
                        try mt.fail("macro tokenizing failed: octal literal overflowed", .{});
                        return error.ParseError;
                    };
                    num += c - '0';
                } else {
                    i += std.fmt.formatIntBuf(bytes[i..], num, 16, .lower, std.fmt.FormatOptions{ .fill = '0', .width = 2 });
                    num = 0;
                    count = 0;
                    if (c == '\\')
                        state = .escape
                    else
                        state = .start;
                    bytes[i] = c;
                    i += 1;
                }
            },
        }
    }
    if (state == .hex or state == .octal)
        i += std.fmt.formatIntBuf(bytes[i..], num, 16, .lower, std.fmt.FormatOptions{ .fill = '0', .width = 2 });
    return bytes[0..i];
}

/// non-ASCII characters (mt > 127) are also treated as non-printable by fmtSliceEscapeLower.
/// If a C string literal or char literal in a macro is not valid UTF-8, we need to escape
/// non-ASCII characters so that the Zig source we output will itself be UTF-8.
fn escapeUnprintables(mt: *MacroTranslator) ![]const u8 {
    const zigified = try mt.zigifyEscapeSequences();
    if (std.unicode.utf8ValidateSlice(zigified)) return zigified;

    const formatter = std.fmt.fmtSliceEscapeLower(zigified);
    const encoded_size = @as(usize, @intCast(std.fmt.count("{s}", .{formatter})));
    const output = try mt.t.arena.alloc(u8, encoded_size);
    return std.fmt.bufPrint(output, "{s}", .{formatter}) catch |err| switch (err) {
        error.NoSpaceLeft => unreachable,
        else => |e| return e,
    };
}

fn parseCPrimaryExpr(mt: *MacroTranslator, scope: *Scope) ParseError!ZigNode {
    const tok = mt.next().?;
    const slice = mt.tokSlice();
    switch (tok) {
        .char_literal,
        .char_literal_utf_8,
        .char_literal_utf_16,
        .char_literal_utf_32,
        .char_literal_wide,
        => {
            if (slice[0] != '\'' or slice[1] == '\\' or slice.len == 3) {
                return ZigTag.char_literal.create(mt.t.arena, try mt.escapeUnprintables());
            } else {
                const str = try std.fmt.allocPrint(mt.t.arena, "0x{s}", .{std.fmt.fmtSliceHexLower(slice[1 .. slice.len - 1])});
                return ZigTag.integer_literal.create(mt.t.arena, str);
            }
        },
        .string_literal,
        .string_literal_utf_16,
        .string_literal_utf_8,
        .string_literal_utf_32,
        .string_literal_wide,
        => {
            return ZigTag.string_literal.create(mt.t.arena, try mt.escapeUnprintables());
        },
        .pp_num => {
            return mt.parseCNumLit();
        },
        .l_paren => {
            const inner_node = try mt.parseCExpr(scope);

            try mt.skip(.r_paren);
            return inner_node;
        },
        else => {},
    }

    // for handling type macros (EVIL)
    // TODO maybe detect and treat type macros as typedefs in parseCSpecifierQualifierList?
    mt.i -= 1;
    if (try mt.parseCTypeName(scope, true)) |type_name| {
        return type_name;
    }
    try mt.fail("unable to translate C expr: unexpected token '{s}'", .{tok.symbol()});
    return error.ParseError;
}

fn macroIntFromBool(mt: *MacroTranslator, node: ZigNode) !ZigNode {
    if (!node.isBoolRes()) {
        return node;
    }

    return ZigTag.int_from_bool.create(mt.t.arena, node);
}

fn macroIntToBool(mt: *MacroTranslator, node: ZigNode) !ZigNode {
    if (node.isBoolRes()) {
        return node;
    }
    if (node.tag() == .string_literal) {
        // @intFromPtr(node) != 0
        const int_from_ptr = try ZigTag.int_from_ptr.create(mt.t.arena, node);
        return ZigTag.not_equal.create(mt.t.arena, .{ .lhs = int_from_ptr, .rhs = ZigTag.zero_literal.init() });
    }
    // node != 0
    return ZigTag.not_equal.create(mt.t.arena, .{ .lhs = node, .rhs = ZigTag.zero_literal.init() });
}

fn parseCCondExpr(mt: *MacroTranslator, scope: *Scope) ParseError!ZigNode {
    const node = try mt.parseCOrExpr(scope);
    if (mt.peek().? != .question_mark) {
        return node;
    }
    _ = mt.next();

    const then_body = try mt.parseCOrExpr(scope);
    try mt.skip(.colon);
    const else_body = try mt.parseCCondExpr(scope);
    return ZigTag.@"if".create(mt.t.arena, .{ .cond = node, .then = then_body, .@"else" = else_body });
}

fn parseCOrExpr(mt: *MacroTranslator, scope: *Scope) ParseError!ZigNode {
    var node = try mt.parseCAndExpr(scope);
    while (mt.next().? == .pipe_pipe) {
        const lhs = try macroIntToBool(mt, node);
        const rhs = try macroIntToBool(mt, try mt.parseCAndExpr(scope));
        node = try ZigTag.@"or".create(mt.t.arena, .{ .lhs = lhs, .rhs = rhs });
    }
    mt.i -= 1;
    return node;
}

fn parseCAndExpr(mt: *MacroTranslator, scope: *Scope) ParseError!ZigNode {
    var node = try mt.parseCBitOrExpr(scope);
    while (mt.next().? == .ampersand_ampersand) {
        const lhs = try macroIntToBool(mt, node);
        const rhs = try macroIntToBool(mt, try mt.parseCBitOrExpr(scope));
        node = try ZigTag.@"and".create(mt.t.arena, .{ .lhs = lhs, .rhs = rhs });
    }
    mt.i -= 1;
    return node;
}

fn parseCBitOrExpr(mt: *MacroTranslator, scope: *Scope) ParseError!ZigNode {
    var node = try mt.parseCBitXorExpr(scope);
    while (mt.next().? == .pipe) {
        const lhs = try macroIntFromBool(mt, node);
        const rhs = try macroIntFromBool(mt, try mt.parseCBitXorExpr(scope));
        node = try ZigTag.bit_or.create(mt.t.arena, .{ .lhs = lhs, .rhs = rhs });
    }
    mt.i -= 1;
    return node;
}

fn parseCBitXorExpr(mt: *MacroTranslator, scope: *Scope) ParseError!ZigNode {
    var node = try mt.parseCBitAndExpr(scope);
    while (mt.next().? == .caret) {
        const lhs = try macroIntFromBool(mt, node);
        const rhs = try macroIntFromBool(mt, try mt.parseCBitAndExpr(scope));
        node = try ZigTag.bit_xor.create(mt.t.arena, .{ .lhs = lhs, .rhs = rhs });
    }
    mt.i -= 1;
    return node;
}

fn parseCBitAndExpr(mt: *MacroTranslator, scope: *Scope) ParseError!ZigNode {
    var node = try mt.parseCEqExpr(scope);
    while (mt.next().? == .ampersand) {
        const lhs = try macroIntFromBool(mt, node);
        const rhs = try macroIntFromBool(mt, try mt.parseCEqExpr(scope));
        node = try ZigTag.bit_and.create(mt.t.arena, .{ .lhs = lhs, .rhs = rhs });
    }
    mt.i -= 1;
    return node;
}

fn parseCEqExpr(mt: *MacroTranslator, scope: *Scope) ParseError!ZigNode {
    var node = try mt.parseCRelExpr(scope);
    while (true) {
        switch (mt.peek().?) {
            .bang_equal => {
                _ = mt.next();
                const lhs = try macroIntFromBool(mt, node);
                const rhs = try macroIntFromBool(mt, try mt.parseCRelExpr(scope));
                node = try ZigTag.not_equal.create(mt.t.arena, .{ .lhs = lhs, .rhs = rhs });
            },
            .equal_equal => {
                _ = mt.next();
                const lhs = try macroIntFromBool(mt, node);
                const rhs = try macroIntFromBool(mt, try mt.parseCRelExpr(scope));
                node = try ZigTag.equal.create(mt.t.arena, .{ .lhs = lhs, .rhs = rhs });
            },
            else => return node,
        }
    }
}

fn parseCRelExpr(mt: *MacroTranslator, scope: *Scope) ParseError!ZigNode {
    var node = try mt.parseCShiftExpr(scope);
    while (true) {
        switch (mt.peek().?) {
            .angle_bracket_right => {
                _ = mt.next();
                const lhs = try macroIntFromBool(mt, node);
                const rhs = try macroIntFromBool(mt, try mt.parseCShiftExpr(scope));
                node = try ZigTag.greater_than.create(mt.t.arena, .{ .lhs = lhs, .rhs = rhs });
            },
            .angle_bracket_right_equal => {
                _ = mt.next();
                const lhs = try macroIntFromBool(mt, node);
                const rhs = try macroIntFromBool(mt, try mt.parseCShiftExpr(scope));
                node = try ZigTag.greater_than_equal.create(mt.t.arena, .{ .lhs = lhs, .rhs = rhs });
            },
            .angle_bracket_left => {
                _ = mt.next();
                const lhs = try macroIntFromBool(mt, node);
                const rhs = try macroIntFromBool(mt, try mt.parseCShiftExpr(scope));
                node = try ZigTag.less_than.create(mt.t.arena, .{ .lhs = lhs, .rhs = rhs });
            },
            .angle_bracket_left_equal => {
                _ = mt.next();
                const lhs = try macroIntFromBool(mt, node);
                const rhs = try macroIntFromBool(mt, try mt.parseCShiftExpr(scope));
                node = try ZigTag.less_than_equal.create(mt.t.arena, .{ .lhs = lhs, .rhs = rhs });
            },
            else => return node,
        }
    }
}

fn parseCShiftExpr(mt: *MacroTranslator, scope: *Scope) ParseError!ZigNode {
    var node = try mt.parseCAddSubExpr(scope);
    while (true) {
        switch (mt.peek().?) {
            .angle_bracket_angle_bracket_left => {
                _ = mt.next();
                const lhs = try macroIntFromBool(mt, node);
                const rhs = try macroIntFromBool(mt, try mt.parseCAddSubExpr(scope));
                node = try ZigTag.shl.create(mt.t.arena, .{ .lhs = lhs, .rhs = rhs });
            },
            .angle_bracket_angle_bracket_right => {
                _ = mt.next();
                const lhs = try macroIntFromBool(mt, node);
                const rhs = try macroIntFromBool(mt, try mt.parseCAddSubExpr(scope));
                node = try ZigTag.shr.create(mt.t.arena, .{ .lhs = lhs, .rhs = rhs });
            },
            else => return node,
        }
    }
}

fn parseCAddSubExpr(mt: *MacroTranslator, scope: *Scope) ParseError!ZigNode {
    var node = try mt.parseCMulExpr(scope);
    while (true) {
        switch (mt.peek().?) {
            .plus => {
                _ = mt.next();
                const lhs = try macroIntFromBool(mt, node);
                const rhs = try macroIntFromBool(mt, try mt.parseCMulExpr(scope));
                node = try ZigTag.add.create(mt.t.arena, .{ .lhs = lhs, .rhs = rhs });
            },
            .minus => {
                _ = mt.next();
                const lhs = try macroIntFromBool(mt, node);
                const rhs = try macroIntFromBool(mt, try mt.parseCMulExpr(scope));
                node = try ZigTag.sub.create(mt.t.arena, .{ .lhs = lhs, .rhs = rhs });
            },
            else => return node,
        }
    }
}

fn parseCMulExpr(mt: *MacroTranslator, scope: *Scope) ParseError!ZigNode {
    var node = try mt.parseCCastExpr(scope);
    while (true) {
        switch (mt.next().?) {
            .asterisk => {
                const lhs = try macroIntFromBool(mt, node);
                const rhs = try macroIntFromBool(mt, try mt.parseCCastExpr(scope));
                node = try ZigTag.mul.create(mt.t.arena, .{ .lhs = lhs, .rhs = rhs });
            },
            .slash => {
                const lhs = try macroIntFromBool(mt, node);
                const rhs = try macroIntFromBool(mt, try mt.parseCCastExpr(scope));
                node = try mt.t.createHelperCallNode(.div, &.{ lhs, rhs });
            },
            .percent => {
                const lhs = try macroIntFromBool(mt, node);
                const rhs = try macroIntFromBool(mt, try mt.parseCCastExpr(scope));
                node = try mt.t.createHelperCallNode(.rem, &.{ lhs, rhs });
            },
            else => {
                mt.i -= 1;
                return node;
            },
        }
    }
}

fn parseCCastExpr(mt: *MacroTranslator, scope: *Scope) ParseError!ZigNode {
    switch (mt.next().?) {
        .l_paren => {
            if (try mt.parseCTypeName(scope, true)) |type_name| {
                while (true) {
                    const next_token = mt.next().?;
                    switch (next_token) {
                        .r_paren => break,
                        else => |next_tag| {
                            // Skip trailing blank defined before the RParen.
                            if ((next_tag == .identifier or next_tag == .extended_identifier) and
                                mt.t.global_scope.blank_macros.contains(mt.tokSlice()))
                                continue;

                            try mt.fail(
                                "unable to translate C expr: expected ')' instead got '{s}'",
                                .{next_token.symbol()},
                            );
                            return error.ParseError;
                        },
                    }
                }
                if (mt.peek().? == .l_brace) {
                    // initializer list
                    return mt.parseCPostfixExpr(scope, type_name);
                }
                const node_to_cast = try mt.parseCCastExpr(scope);
                return mt.t.createHelperCallNode(.cast, &.{ type_name, node_to_cast });
            }
        },
        else => {},
    }
    mt.i -= 1;
    return mt.parseCUnaryExpr(scope);
}

// allow_fail is set when unsure if we are parsing a type-name
fn parseCTypeName(mt: *MacroTranslator, scope: *Scope, allow_fail: bool) ParseError!?ZigNode {
    if (try mt.parseCSpecifierQualifierList(scope, allow_fail)) |node| {
        return try mt.parseCAbstractDeclarator(node);
    } else {
        return null;
    }
}

fn parseCSpecifierQualifierList(mt: *MacroTranslator, scope: *Scope, allow_fail: bool) ParseError!?ZigNode {
    const tok = mt.next().?;
    switch (tok) {
        .macro_param, .macro_param_no_expand => {
            return try ZigTag.identifier.create(mt.t.arena, mt.macro.params[mt.tokens[mt.i].end]);
        },
        .identifier, .extended_identifier => {
            const slice = mt.tokSlice();
            const mangled_name = scope.getAlias(slice) orelse slice;
            if (mt.t.global_scope.blank_macros.contains(mt.tokSlice())) {
                return try mt.parseCSpecifierQualifierList(scope, allow_fail);
            }
            if (!allow_fail or mt.t.typedefs.contains(mangled_name)) {
                if (Translator.builtin_typedef_map.get(mangled_name)) |ty| return try ZigTag.type.create(mt.t.arena, ty);
                return try ZigTag.identifier.create(mt.t.arena, mangled_name);
            }
        },
        .keyword_void => return try ZigTag.type.create(mt.t.arena, "anyopaque"),
        .keyword_bool => return try ZigTag.type.create(mt.t.arena, "bool"),
        .keyword_char,
        .keyword_int,
        .keyword_short,
        .keyword_long,
        .keyword_float,
        .keyword_double,
        .keyword_signed,
        .keyword_unsigned,
        .keyword_complex,
        => {
            mt.i -= 1;
            return try mt.parseCNumericType();
        },
        .keyword_enum, .keyword_struct, .keyword_union => {
            const tag_name = mt.tokSlice();
            // struct Foo will be declared as struct_Foo by transRecordDecl
            try mt.skip(.identifier);

            const name = try std.fmt.allocPrint(mt.t.arena, "{s}_{s}", .{ tag_name, mt.tokSlice() });
            return try ZigTag.identifier.create(mt.t.arena, name);
        },
        else => {},
    }

    if (allow_fail) {
        mt.i -= 1;
        return null;
    } else {
        try mt.fail("unable to translate C expr: unexpected token '{s}'", .{tok.symbol()});
        return error.ParseError;
    }
}

fn parseCNumericType(mt: *MacroTranslator) ParseError!ZigNode {
    const KwCounter = struct {
        double: u8 = 0,
        long: u8 = 0,
        int: u8 = 0,
        float: u8 = 0,
        short: u8 = 0,
        char: u8 = 0,
        unsigned: u8 = 0,
        signed: u8 = 0,
        complex: u8 = 0,

        fn eql(self: @This(), other: @This()) bool {
            return std.meta.eql(self, other);
        }
    };

    // Yes, these can be in *any* order
    // This still doesn't cover cases where for example volatile is intermixed

    var kw = KwCounter{};
    // prevent overflow
    var i: u8 = 0;
    while (i < math.maxInt(u8)) : (i += 1) {
        switch (mt.next().?) {
            .keyword_double => kw.double += 1,
            .keyword_long => kw.long += 1,
            .keyword_int => kw.int += 1,
            .keyword_float => kw.float += 1,
            .keyword_short => kw.short += 1,
            .keyword_char => kw.char += 1,
            .keyword_unsigned => kw.unsigned += 1,
            .keyword_signed => kw.signed += 1,
            .keyword_complex => kw.complex += 1,
            else => {
                mt.i -= 1;
                break;
            },
        }
    }

    if (kw.eql(.{ .int = 1 }) or kw.eql(.{ .signed = 1 }) or kw.eql(.{ .signed = 1, .int = 1 }))
        return ZigTag.type.create(mt.t.arena, "c_int");

    if (kw.eql(.{ .unsigned = 1 }) or kw.eql(.{ .unsigned = 1, .int = 1 }))
        return ZigTag.type.create(mt.t.arena, "c_uint");

    if (kw.eql(.{ .long = 1 }) or kw.eql(.{ .signed = 1, .long = 1 }) or kw.eql(.{ .long = 1, .int = 1 }) or kw.eql(.{ .signed = 1, .long = 1, .int = 1 }))
        return ZigTag.type.create(mt.t.arena, "c_long");

    if (kw.eql(.{ .unsigned = 1, .long = 1 }) or kw.eql(.{ .unsigned = 1, .long = 1, .int = 1 }))
        return ZigTag.type.create(mt.t.arena, "c_ulong");

    if (kw.eql(.{ .long = 2 }) or kw.eql(.{ .signed = 1, .long = 2 }) or kw.eql(.{ .long = 2, .int = 1 }) or kw.eql(.{ .signed = 1, .long = 2, .int = 1 }))
        return ZigTag.type.create(mt.t.arena, "c_longlong");

    if (kw.eql(.{ .unsigned = 1, .long = 2 }) or kw.eql(.{ .unsigned = 1, .long = 2, .int = 1 }))
        return ZigTag.type.create(mt.t.arena, "c_ulonglong");

    if (kw.eql(.{ .signed = 1, .char = 1 }))
        return ZigTag.type.create(mt.t.arena, "i8");

    if (kw.eql(.{ .char = 1 }) or kw.eql(.{ .unsigned = 1, .char = 1 }))
        return ZigTag.type.create(mt.t.arena, "u8");

    if (kw.eql(.{ .short = 1 }) or kw.eql(.{ .signed = 1, .short = 1 }) or kw.eql(.{ .short = 1, .int = 1 }) or kw.eql(.{ .signed = 1, .short = 1, .int = 1 }))
        return ZigTag.type.create(mt.t.arena, "c_short");

    if (kw.eql(.{ .unsigned = 1, .short = 1 }) or kw.eql(.{ .unsigned = 1, .short = 1, .int = 1 }))
        return ZigTag.type.create(mt.t.arena, "c_ushort");

    if (kw.eql(.{ .float = 1 }))
        return ZigTag.type.create(mt.t.arena, "f32");

    if (kw.eql(.{ .double = 1 }))
        return ZigTag.type.create(mt.t.arena, "f64");

    if (kw.eql(.{ .long = 1, .double = 1 })) {
        try mt.fail("unable to translate: TODO long double", .{});
        return error.ParseError;
    }

    if (kw.eql(.{ .float = 1, .complex = 1 })) {
        try mt.fail("unable to translate: TODO _Complex", .{});
        return error.ParseError;
    }

    if (kw.eql(.{ .double = 1, .complex = 1 })) {
        try mt.fail("unable to translate: TODO _Complex", .{});
        return error.ParseError;
    }

    if (kw.eql(.{ .long = 1, .double = 1, .complex = 1 })) {
        try mt.fail("unable to translate: TODO _Complex", .{});
        return error.ParseError;
    }

    try mt.fail("unable to translate: invalid numeric type", .{});
    return error.ParseError;
}

fn parseCAbstractDeclarator(mt: *MacroTranslator, node: ZigNode) ParseError!ZigNode {
    switch (mt.next().?) {
        .asterisk => {
            // last token of `node`
            const prev_id = mt.tokens[mt.i - 1].id;

            if (prev_id == .keyword_void) {
                const ptr = try ZigTag.single_pointer.create(mt.t.arena, .{
                    .is_const = false,
                    .is_volatile = false,
                    .elem_type = node,
                });
                return ZigTag.optional_type.create(mt.t.arena, ptr);
            } else {
                return ZigTag.c_pointer.create(mt.t.arena, .{
                    .is_const = false,
                    .is_volatile = false,
                    .elem_type = node,
                });
            }
        },
        else => {
            mt.i -= 1;
            return node;
        },
    }
}

fn parseCPostfixExpr(mt: *MacroTranslator, scope: *Scope, type_name: ?ZigNode) ParseError!ZigNode {
    var node = try mt.parseCPostfixExprInner(scope, type_name);
    // In C the preprocessor would handle concatting strings while expanding macros.
    // This should do approximately the same by concatting any strings and identifiers
    // after a primary or postfix expression.
    while (true) {
        switch (mt.peek().?) {
            .string_literal,
            .string_literal_utf_16,
            .string_literal_utf_8,
            .string_literal_utf_32,
            .string_literal_wide,
            => {},
            .identifier, .extended_identifier => {
                const tok = mt.tokens[mt.i + 1];
                const slice = mt.source[tok.start..tok.end];
                if (mt.t.global_scope.blank_macros.contains(slice)) {
                    mt.i += 1;
                    continue;
                }
            },
            else => break,
        }
        const rhs = try mt.parseCPostfixExprInner(scope, type_name);
        node = try ZigTag.array_cat.create(mt.t.arena, .{ .lhs = node, .rhs = rhs });
    }
    return node;
}

fn parseCPostfixExprInner(mt: *MacroTranslator, scope: *Scope, type_name: ?ZigNode) ParseError!ZigNode {
    var node = type_name orelse try mt.parseCPrimaryExpr(scope);
    while (true) {
        switch (mt.next().?) {
            .period => {
                try mt.skip(.identifier);

                node = try ZigTag.field_access.create(mt.t.arena, .{ .lhs = node, .field_name = mt.tokSlice() });
            },
            .arrow => {
                try mt.skip(.identifier);

                const deref = try ZigTag.deref.create(mt.t.arena, node);
                node = try ZigTag.field_access.create(mt.t.arena, .{ .lhs = deref, .field_name = mt.tokSlice() });
            },
            .l_bracket => {
                const index_val = try macroIntFromBool(mt, try mt.parseCExpr(scope));
                const index = try ZigTag.as.create(mt.t.arena, .{
                    .lhs = try ZigTag.type.create(mt.t.arena, "usize"),
                    .rhs = try ZigTag.int_cast.create(mt.t.arena, index_val),
                });
                node = try ZigTag.array_access.create(mt.t.arena, .{ .lhs = node, .rhs = index });
                try mt.skip(.r_bracket);
            },
            .l_paren => {
                if (mt.peek().? == .r_paren) {
                    mt.i += 1;
                    node = try ZigTag.call.create(mt.t.arena, .{ .lhs = node, .args = &[0]ZigNode{} });
                } else {
                    var args = std.ArrayList(ZigNode).init(mt.t.gpa);
                    defer args.deinit();
                    while (true) {
                        const arg = try mt.parseCCondExpr(scope);
                        try args.append(arg);
                        const next_id = mt.next().?;
                        switch (next_id) {
                            .comma => {},
                            .r_paren => break,
                            else => {
                                try mt.fail("unable to translate C expr: expected ',' or ')' instead got '{s}'", .{next_id.symbol()});
                                return error.ParseError;
                            },
                        }
                    }
                    node = try ZigTag.call.create(mt.t.arena, .{ .lhs = node, .args = try mt.t.arena.dupe(ZigNode, args.items) });
                }
            },
            .l_brace => {
                // Check for designated field initializers
                if (mt.peek().? == .period) {
                    var init_vals = std.ArrayList(ast.Payload.ContainerInitDot.Initializer).init(mt.t.gpa);
                    defer init_vals.deinit();

                    while (true) {
                        try mt.skip(.period);
                        try mt.skip(.identifier);
                        const name = mt.tokSlice();
                        try mt.skip(.equal);

                        const val = try mt.parseCCondExpr(scope);
                        try init_vals.append(.{ .name = name, .value = val });
                        const next_id = mt.next().?;
                        switch (next_id) {
                            .comma => {},
                            .r_brace => break,
                            else => {
                                try mt.fail("unable to translate C expr: expected ',' or '}}' instead got '{s}'", .{next_id.symbol()});
                                return error.ParseError;
                            },
                        }
                    }
                    const tuple_node = try ZigTag.container_init_dot.create(mt.t.arena, try mt.t.arena.dupe(ast.Payload.ContainerInitDot.Initializer, init_vals.items));
                    node = try ZigTag.std_mem_zeroinit.create(mt.t.arena, .{ .lhs = node, .rhs = tuple_node });
                    continue;
                }

                var init_vals = std.ArrayList(ZigNode).init(mt.t.gpa);
                defer init_vals.deinit();

                while (true) {
                    const val = try mt.parseCCondExpr(scope);
                    try init_vals.append(val);
                    const next_id = mt.next().?;
                    switch (next_id) {
                        .comma => {},
                        .r_brace => break,
                        else => {
                            try mt.fail("unable to translate C expr: expected ',' or '}}' instead got '{s}'", .{next_id.symbol()});
                            return error.ParseError;
                        },
                    }
                }
                const tuple_node = try ZigTag.tuple.create(mt.t.arena, try mt.t.arena.dupe(ZigNode, init_vals.items));
                node = try ZigTag.std_mem_zeroinit.create(mt.t.arena, .{ .lhs = node, .rhs = tuple_node });
            },
            .plus_plus, .minus_minus => {
                try mt.fail("TODO postfix inc/dec expr", .{});
                return error.ParseError;
            },
            else => {
                mt.i -= 1;
                return node;
            },
        }
    }
}

fn parseCUnaryExpr(mt: *MacroTranslator, scope: *Scope) ParseError!ZigNode {
    switch (mt.next().?) {
        .bang => {
            const operand = try macroIntToBool(mt, try mt.parseCCastExpr(scope));
            return ZigTag.not.create(mt.t.arena, operand);
        },
        .minus => {
            const operand = try macroIntFromBool(mt, try mt.parseCCastExpr(scope));
            return ZigTag.negate.create(mt.t.arena, operand);
        },
        .plus => return try mt.parseCCastExpr(scope),
        .tilde => {
            const operand = try macroIntFromBool(mt, try mt.parseCCastExpr(scope));
            return ZigTag.bit_not.create(mt.t.arena, operand);
        },
        .asterisk => {
            const operand = try mt.parseCCastExpr(scope);
            return ZigTag.deref.create(mt.t.arena, operand);
        },
        .ampersand => {
            const operand = try mt.parseCCastExpr(scope);
            return ZigTag.address_of.create(mt.t.arena, operand);
        },
        .keyword_sizeof => {
            const operand = if (mt.peek().? == .l_paren) blk: {
                _ = mt.next();
                const inner = (try mt.parseCTypeName(scope, false)).?;
                try mt.skip(.r_paren);
                break :blk inner;
            } else try mt.parseCUnaryExpr(scope);

            return mt.t.createHelperCallNode(.sizeof, &.{ operand });
        },
        .keyword_alignof => {
            // TODO this won't work if using <stdalign.h>'s
            // #define alignof _Alignof
            try mt.skip(.l_paren);
            const operand = (try mt.parseCTypeName(scope, false)).?;
            try mt.skip(.r_paren);

            return ZigTag.alignof.create(mt.t.arena, operand);
        },
        .plus_plus, .minus_minus => {
            try mt.fail("TODO unary inc/dec expr", .{});
            return error.ParseError;
        },
        else => {},
    }

    mt.i -= 1;
    return try mt.parseCPostfixExpr(scope, null);
}
