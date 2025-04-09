const std = @import("std");
const mem = std.mem;
const assert = std.debug.assert;

const aro = @import("aro");
const CToken = aro.Tokenizer.Token;

const ast = @import("ast.zig");
const ZigNode = ast.Node;
const ZigTag = ZigNode.Tag;
const builtins = @import("builtins.zig");
const helpers = @import("helpers.zig");
const PatternList = @import("PatternList.zig");
const Translator = @import("Translator.zig");

const Error = Translator.Error;
pub const ParseError = Error || error{ParseError};

const MacroTranslator = @This();

t: *Translator,
macro: aro.Preprocessor.Macro,
name: []const u8,

tokens: []const CToken,
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
            mt.t,
            "unable to translate C expr: expected '{s}' instead got '{s}'",
            .{ expected_id.symbol(), next_id.symbol() },
        );
        return error.ParseError;
    }
}

fn fail(mt: *MacroTranslator, comptime fmt: []const u8, args: anytype) !void {
    return mt.t.failDeclExtra(mt.macro.loc, mt.name, fmt, args);
}

pub fn transFnMacro(mt: *MacroTranslator) ParseError!void {
    _ = mt;
}

pub fn transMacro(mt: *MacroTranslator) ParseError!void {
    _ = mt;
}
