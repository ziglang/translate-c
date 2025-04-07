const std = @import("std");
const mem = std.mem;
const assert = std.debug.assert;

const aro = @import("aro");
const CToken = aro.Tokenizer.Token;

const Translator = @import("Translator.zig");
const Error = Translator.Error;
pub const MacroProcessingError = Error || error{UnexpectedMacroToken};

// Maps macro parameter names to token position, for determining if different
// identifiers refer to the same positional argument in different macros.
const ArgsPositionMap = std.StringArrayHashMapUnmanaged(usize);

const PatternList = @This();

patterns: []Pattern,

/// Templates must be function-like macros
/// first element is macro source, second element is the name of the function
/// in __helpers which implements it
const templates = [_][2][]const u8{
    [2][]const u8{ "f_SUFFIX(X) (X ## f)", "F_SUFFIX" },
    [2][]const u8{ "F_SUFFIX(X) (X ## F)", "F_SUFFIX" },

    [2][]const u8{ "u_SUFFIX(X) (X ## u)", "U_SUFFIX" },
    [2][]const u8{ "U_SUFFIX(X) (X ## U)", "U_SUFFIX" },

    [2][]const u8{ "l_SUFFIX(X) (X ## l)", "L_SUFFIX" },
    [2][]const u8{ "L_SUFFIX(X) (X ## L)", "L_SUFFIX" },

    [2][]const u8{ "ul_SUFFIX(X) (X ## ul)", "UL_SUFFIX" },
    [2][]const u8{ "uL_SUFFIX(X) (X ## uL)", "UL_SUFFIX" },
    [2][]const u8{ "Ul_SUFFIX(X) (X ## Ul)", "UL_SUFFIX" },
    [2][]const u8{ "UL_SUFFIX(X) (X ## UL)", "UL_SUFFIX" },

    [2][]const u8{ "ll_SUFFIX(X) (X ## ll)", "LL_SUFFIX" },
    [2][]const u8{ "LL_SUFFIX(X) (X ## LL)", "LL_SUFFIX" },

    [2][]const u8{ "ull_SUFFIX(X) (X ## ull)", "ULL_SUFFIX" },
    [2][]const u8{ "uLL_SUFFIX(X) (X ## uLL)", "ULL_SUFFIX" },
    [2][]const u8{ "Ull_SUFFIX(X) (X ## Ull)", "ULL_SUFFIX" },
    [2][]const u8{ "ULL_SUFFIX(X) (X ## ULL)", "ULL_SUFFIX" },

    [2][]const u8{ "f_SUFFIX(X) X ## f", "F_SUFFIX" },
    [2][]const u8{ "F_SUFFIX(X) X ## F", "F_SUFFIX" },

    [2][]const u8{ "u_SUFFIX(X) X ## u", "U_SUFFIX" },
    [2][]const u8{ "U_SUFFIX(X) X ## U", "U_SUFFIX" },

    [2][]const u8{ "l_SUFFIX(X) X ## l", "L_SUFFIX" },
    [2][]const u8{ "L_SUFFIX(X) X ## L", "L_SUFFIX" },

    [2][]const u8{ "ul_SUFFIX(X) X ## ul", "UL_SUFFIX" },
    [2][]const u8{ "uL_SUFFIX(X) X ## uL", "UL_SUFFIX" },
    [2][]const u8{ "Ul_SUFFIX(X) X ## Ul", "UL_SUFFIX" },
    [2][]const u8{ "UL_SUFFIX(X) X ## UL", "UL_SUFFIX" },

    [2][]const u8{ "ll_SUFFIX(X) X ## ll", "LL_SUFFIX" },
    [2][]const u8{ "LL_SUFFIX(X) X ## LL", "LL_SUFFIX" },

    [2][]const u8{ "ull_SUFFIX(X) X ## ull", "ULL_SUFFIX" },
    [2][]const u8{ "uLL_SUFFIX(X) X ## uLL", "ULL_SUFFIX" },
    [2][]const u8{ "Ull_SUFFIX(X) X ## Ull", "ULL_SUFFIX" },
    [2][]const u8{ "ULL_SUFFIX(X) X ## ULL", "ULL_SUFFIX" },

    [2][]const u8{ "CAST_OR_CALL(X, Y) (X)(Y)", "CAST_OR_CALL" },
    [2][]const u8{ "CAST_OR_CALL(X, Y) ((X)(Y))", "CAST_OR_CALL" },

    [2][]const u8{
        \\wl_container_of(ptr, sample, member)                     \
        \\(__typeof__(sample))((char *)(ptr) -                     \
        \\     offsetof(__typeof__(*sample), member))
        ,
        "WL_CONTAINER_OF",
    },

    [2][]const u8{ "IGNORE_ME(X) ((void)(X))", "DISCARD" },
    [2][]const u8{ "IGNORE_ME(X) (void)(X)", "DISCARD" },
    [2][]const u8{ "IGNORE_ME(X) ((const void)(X))", "DISCARD" },
    [2][]const u8{ "IGNORE_ME(X) (const void)(X)", "DISCARD" },
    [2][]const u8{ "IGNORE_ME(X) ((volatile void)(X))", "DISCARD" },
    [2][]const u8{ "IGNORE_ME(X) (volatile void)(X)", "DISCARD" },
    [2][]const u8{ "IGNORE_ME(X) ((const volatile void)(X))", "DISCARD" },
    [2][]const u8{ "IGNORE_ME(X) (const volatile void)(X)", "DISCARD" },
    [2][]const u8{ "IGNORE_ME(X) ((volatile const void)(X))", "DISCARD" },
    [2][]const u8{ "IGNORE_ME(X) (volatile const void)(X)", "DISCARD" },
};

/// Assumes that `ms` represents a tokenized function-like macro.
fn buildArgsHash(allocator: mem.Allocator, ms: MacroSlicer, hash: *ArgsPositionMap) MacroProcessingError!void {
    assert(ms.tokens.len > 2);
    assert(ms.tokens[0].id == .identifier or ms.tokens[0].id == .extended_identifier);
    assert(ms.tokens[1].id == .l_paren);

    var i: usize = 2;
    while (true) : (i += 1) {
        const token = ms.tokens[i];
        switch (token.id) {
            .r_paren => break,
            .comma => continue,
            .identifier, .extended_identifier => {
                const identifier = ms.slice(token);
                try hash.put(allocator, identifier, i);
            },
            else => return error.UnexpectedMacroToken,
        }
    }
}

const Pattern = struct {
    tokens: []const CToken,
    source: []const u8,
    impl: []const u8,
    args_hash: ArgsPositionMap,

    fn init(pl: *Pattern, allocator: mem.Allocator, template: [2][]const u8) Error!void {
        const source = template[0];
        const impl = template[1];

        var tok_list = std.ArrayList(CToken).init(allocator);
        defer tok_list.deinit();
        try tokenizeMacro(source, &tok_list);
        const tokens = try allocator.dupe(CToken, tok_list.items);

        pl.* = .{
            .tokens = tokens,
            .source = source,
            .impl = impl,
            .args_hash = .{},
        };
        const ms = MacroSlicer{ .source = source, .tokens = tokens };
        buildArgsHash(allocator, ms, &pl.args_hash) catch |err| switch (err) {
            error.UnexpectedMacroToken => unreachable,
            else => |e| return e,
        };
    }

    fn deinit(pl: *Pattern, allocator: mem.Allocator) void {
        pl.args_hash.deinit(allocator);
        allocator.free(pl.tokens);
    }

    /// This function assumes that `ms` has already been validated to contain a function-like
    /// macro, and that the parsed template macro in `pl` also contains a function-like
    /// macro. Please review this logic carefully if changing that assumption. Two
    /// function-like macros are considered equivalent if and only if they contain the same
    /// list of tokens, modulo parameter names.
    fn isEquivalent(pl: Pattern, ms: MacroSlicer, args_hash: ArgsPositionMap) bool {
        if (pl.tokens.len != ms.tokens.len) return false;
        if (args_hash.count() != pl.args_hash.count()) return false;

        var i: usize = 2;
        while (pl.tokens[i].id != .r_paren) : (i += 1) {}

        const pattern_slicer = MacroSlicer{ .source = pl.source, .tokens = pl.tokens };
        while (i < pl.tokens.len) : (i += 1) {
            const pattern_token = pl.tokens[i];
            const macro_token = ms.tokens[i];
            if (pattern_token.id != macro_token.id) return false;

            const pattern_bytes = pattern_slicer.slice(pattern_token);
            const macro_bytes = ms.slice(macro_token);
            switch (pattern_token.id) {
                .identifier, .extended_identifier => {
                    const pattern_arg_index = pl.args_hash.get(pattern_bytes);
                    const macro_arg_index = args_hash.get(macro_bytes);

                    if (pattern_arg_index == null and macro_arg_index == null) {
                        if (!mem.eql(u8, pattern_bytes, macro_bytes)) return false;
                    } else if (pattern_arg_index != null and macro_arg_index != null) {
                        if (pattern_arg_index.? != macro_arg_index.?) return false;
                    } else {
                        return false;
                    }
                },
                .string_literal, .char_literal, .pp_num => {
                    if (!mem.eql(u8, pattern_bytes, macro_bytes)) return false;
                },
                else => {
                    // other tags correspond to keywords and operators that do not contain a "payload"
                    // that can vary
                },
            }
        }
        return true;
    }
};

fn init(allocator: mem.Allocator) Error!PatternList {
    const patterns = try allocator.alloc(Pattern, templates.len);
    for (templates, 0..) |template, i| {
        try patterns[i].init(allocator, template);
    }
    return .{ .patterns = patterns };
}

fn deinit(pl: *PatternList, allocator: mem.Allocator) void {
    for (pl.patterns) |*pattern| pattern.deinit(allocator);
    allocator.free(pl.patterns);
    pl.* = undefined;
}

fn match(pl: PatternList, allocator: mem.Allocator, ms: MacroSlicer) Error!?Pattern {
    var args_hash: ArgsPositionMap = .{};
    defer args_hash.deinit(allocator);

    buildArgsHash(allocator, ms, &args_hash) catch |err| switch (err) {
        error.UnexpectedMacroToken => return null,
        else => |e| return e,
    };

    for (pl.patterns) |pattern| if (pattern.isEquivalent(ms, args_hash)) return pattern;
    return null;
}

test "Macro matching" {
    const testing = std.testing;
    const helper = struct {
        fn checkMacro(allocator: mem.Allocator, pattern_list: PatternList, source: []const u8, comptime expected_match: ?[]const u8) !void {
            var tok_list = std.ArrayList(CToken).init(allocator);
            defer tok_list.deinit();
            try tokenizeMacro(source, &tok_list);
            const macro_slicer: MacroSlicer = .{ .source = source, .tokens = tok_list.items };
            const matched = try pattern_list.match(allocator, macro_slicer);
            if (expected_match) |expected| {
                try testing.expectEqualStrings(expected, matched.?.impl);
                try testing.expect(@hasDecl(@import("helpers.zig").sources, expected));
            } else {
                try testing.expectEqual(@as(@TypeOf(matched), null), matched);
            }
        }
    };
    const allocator = std.testing.allocator;
    var pattern_list = try PatternList.init(allocator);
    defer pattern_list.deinit(allocator);

    try helper.checkMacro(allocator, pattern_list, "BAR(Z) (Z ## F)", "F_SUFFIX");
    try helper.checkMacro(allocator, pattern_list, "BAR(Z) (Z ## U)", "U_SUFFIX");
    try helper.checkMacro(allocator, pattern_list, "BAR(Z) (Z ## L)", "L_SUFFIX");
    try helper.checkMacro(allocator, pattern_list, "BAR(Z) (Z ## LL)", "LL_SUFFIX");
    try helper.checkMacro(allocator, pattern_list, "BAR(Z) (Z ## UL)", "UL_SUFFIX");
    try helper.checkMacro(allocator, pattern_list, "BAR(Z) (Z ## ULL)", "ULL_SUFFIX");
    try helper.checkMacro(allocator, pattern_list,
        \\container_of(a, b, c)                             \
        \\(__typeof__(b))((char *)(a) -                     \
        \\     offsetof(__typeof__(*b), c))
    , "WL_CONTAINER_OF");

    try helper.checkMacro(allocator, pattern_list, "NO_MATCH(X, Y) (X + Y)", null);
    try helper.checkMacro(allocator, pattern_list, "CAST_OR_CALL(X, Y) (X)(Y)", "CAST_OR_CALL");
    try helper.checkMacro(allocator, pattern_list, "CAST_OR_CALL(X, Y) ((X)(Y))", "CAST_OR_CALL");
    try helper.checkMacro(allocator, pattern_list, "IGNORE_ME(X) (void)(X)", "DISCARD");
    try helper.checkMacro(allocator, pattern_list, "IGNORE_ME(X) ((void)(X))", "DISCARD");
    try helper.checkMacro(allocator, pattern_list, "IGNORE_ME(X) (const void)(X)", "DISCARD");
    try helper.checkMacro(allocator, pattern_list, "IGNORE_ME(X) ((const void)(X))", "DISCARD");
    try helper.checkMacro(allocator, pattern_list, "IGNORE_ME(X) (volatile void)(X)", "DISCARD");
    try helper.checkMacro(allocator, pattern_list, "IGNORE_ME(X) ((volatile void)(X))", "DISCARD");
    try helper.checkMacro(allocator, pattern_list, "IGNORE_ME(X) (const volatile void)(X)", "DISCARD");
    try helper.checkMacro(allocator, pattern_list, "IGNORE_ME(X) ((const volatile void)(X))", "DISCARD");
    try helper.checkMacro(allocator, pattern_list, "IGNORE_ME(X) (volatile const void)(X)", "DISCARD");
    try helper.checkMacro(allocator, pattern_list, "IGNORE_ME(X) ((volatile const void)(X))", "DISCARD");
}

const MacroSlicer = struct {
    source: []const u8,
    tokens: []const CToken,

    fn slice(pl: MacroSlicer, token: CToken) []const u8 {
        return pl.source[token.start..token.end];
    }
};

fn tokenizeMacro(source: []const u8, tok_list: *std.ArrayList(CToken)) Error!void {
    var tokenizer: aro.Tokenizer = .{
        .buf = source,
        .source = .unused,
        .langopts = .{},
    };
    while (true) {
        const tok = tokenizer.next();
        switch (tok.id) {
            .whitespace => continue,
            .nl, .eof => {
                try tok_list.append(tok);
                break;
            },
            else => {},
        }
        try tok_list.append(tok);
    }
}
