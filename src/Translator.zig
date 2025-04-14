const std = @import("std");
const mem = std.mem;
const assert = std.debug.assert;
const CallingConvention = std.builtin.CallingConvention;

const aro = @import("aro");
const CToken = aro.Tokenizer.Token;
const Tree = aro.Tree;
const Node = Tree.Node;
const TokenIndex = Tree.TokenIndex;
const QualType = aro.QualType;

const ast = @import("ast.zig");
const ZigNode = ast.Node;
const ZigTag = ZigNode.Tag;
const builtins = @import("builtins.zig");
const helpers = @import("helpers.zig");
const MacroTranslator = @import("MacroTranslator.zig");
const Scope = @import("Scope.zig");

pub const Error = std.mem.Allocator.Error;
pub const MacroProcessingError = Error || error{UnexpectedMacroToken};
pub const TypeError = Error || error{UnsupportedType};
pub const TransError = TypeError || error{UnsupportedTranslation};

const Translator = @This();

/// The C AST to be translated.
tree: *const Tree,
/// The compilation corresponding to the AST.
comp: *aro.Compilation,
/// The Preprocessor that produced the source for `tree`.
pp: *const aro.Preprocessor,

gpa: mem.Allocator,
arena: mem.Allocator,

alias_list: Scope.AliasList,
global_scope: *Scope.Root,
/// Running number used for creating new unique identifiers.
mangle_count: u32 = 0,

/// Table of declarations for enum, struct, union and typedef types.
type_decls: std.AutoArrayHashMapUnmanaged(Node.Index, []const u8) = .empty,
/// Table of record decls that have been demoted to opaques.
opaque_demotes: std.AutoHashMapUnmanaged(QualType, void) = .empty,
/// Table of unnamed enums and records that are child types of typedefs.
unnamed_typedefs: std.AutoHashMapUnmanaged(QualType, []const u8) = .empty,
/// Table of anonymous record to generated field names.
anonymous_record_field_names: std.AutoHashMapUnmanaged(struct {
    parent: QualType,
    field: QualType,
}, []const u8) = .empty,

/// This one is different than the root scope's name table. This contains
/// a list of names that we found by visiting all the top level decls without
/// translating them. The other maps are updated as we translate; this one is updated
/// up front in a pre-processing step.
global_names: std.StringArrayHashMapUnmanaged(void) = .empty,

/// This is similar to `global_names`, but contains names which we would
/// *like* to use, but do not strictly *have* to if they are unavailable.
/// These are relevant to types, which ideally we would name like
/// 'struct_foo' with an alias 'foo', but if either of those names is taken,
/// may be mangled.
/// This is distinct from `global_names` so we can detect at a type
/// declaration whether or not the name is available.
weak_global_names: std.StringArrayHashMapUnmanaged(void) = .empty,

/// Set of builtins whose source needs to be rendered.
needed_builtins: std.StringArrayHashMapUnmanaged([]const u8) = .empty,

/// Set of helpers whose source needs to be rendered.
needed_helpers: std.StringArrayHashMapUnmanaged([]const u8) = .empty,

/// Set of identifiers known to refer to typedef declarations.
/// Used when parsing macros.
typedefs: std.StringArrayHashMapUnmanaged(void) = .empty,

fn getMangle(t: *Translator) u32 {
    t.mangle_count += 1;
    return t.mangle_count;
}

/// Convert an `aro.Source.Location` to a 'file:line:column' string.
fn locStr(t: *Translator, loc: aro.Source.Location) ![]const u8 {
    const source = t.comp.getSource(loc.id);
    const line_col = source.lineCol(loc);
    const filename = source.path;

    const line = source.physicalLine(loc);
    const col = line_col.col;

    return std.fmt.allocPrint(t.arena, "{s}:{d}:{d}", .{ filename, line, col });
}

fn maybeSuppressResult(t: *Translator, used: ResultUsed, result: ZigNode) TransError!ZigNode {
    if (used == .used) return result;
    return ZigTag.discard.create(t.arena, .{ .should_skip = false, .value = result });
}

fn addTopLevelDecl(t: *Translator, name: []const u8, decl_node: ZigNode) !void {
    const gop = try t.global_scope.sym_table.getOrPut(t.gpa, name);
    if (!gop.found_existing) {
        gop.value_ptr.* = decl_node;
        try t.global_scope.nodes.append(t.gpa, decl_node);
    }
}

fn fail(
    t: *Translator,
    err: anytype,
    source_loc: TokenIndex,
    comptime format: []const u8,
    args: anytype,
) (@TypeOf(err) || error{OutOfMemory}) {
    try t.warn(&t.global_scope.base, source_loc, format, args);
    return err;
}

// TODO audit usages, not valid in function scope
pub fn failDecl(t: *Translator, tok_idx: TokenIndex, name: []const u8, comptime format: []const u8, args: anytype) Error!void {
    const loc = t.tree.tokens.items(.loc)[tok_idx];
    return t.failDeclExtra(loc, name, format, args);
}

pub fn failDeclExtra(t: *Translator, loc: aro.Source.Location, name: []const u8, comptime format: []const u8, args: anytype) Error!void {
    // location
    // pub const name = @compileError(msg);
    const fail_msg = try std.fmt.allocPrint(t.arena, format, args);
    try t.addTopLevelDecl(name, try ZigTag.fail_decl.create(t.arena, .{ .actual = name, .mangled = fail_msg }));
    const str = try t.locStr(loc);
    const location_comment = try std.fmt.allocPrint(t.arena, "// {s}", .{str});
    try t.global_scope.nodes.append(t.gpa, try ZigTag.warning.create(t.arena, location_comment));
}

fn warn(t: *Translator, scope: *Scope, tok_idx: TokenIndex, comptime format: []const u8, args: anytype) !void {
    const loc = t.tree.tokens.items(.loc)[tok_idx];
    const str = try t.locStr(loc);
    const value = try std.fmt.allocPrint(t.arena, "\n// {s}: warning: " ++ format, .{str} ++ args);
    try scope.appendNode(try ZigTag.warning.create(t.arena, value));
}

pub fn translate(
    gpa: mem.Allocator,
    comp: *aro.Compilation,
    pp: *const aro.Preprocessor,
    tree: *const aro.Tree,
) ![]u8 {
    var arena_allocator = std.heap.ArenaAllocator.init(gpa);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    var translator: Translator = .{
        .gpa = gpa,
        .arena = arena,
        .alias_list = .empty,
        .global_scope = try arena.create(Scope.Root),
        .comp = comp,
        .pp = pp,
        .tree = tree,
    };
    translator.global_scope.* = Scope.Root.init(&translator);
    defer {
        translator.type_decls.deinit(gpa);
        translator.alias_list.deinit(gpa);
        translator.global_names.deinit(gpa);
        translator.weak_global_names.deinit(gpa);
        translator.opaque_demotes.deinit(gpa);
        translator.unnamed_typedefs.deinit(gpa);
        translator.anonymous_record_field_names.deinit(gpa);
        translator.typedefs.deinit(gpa);
        translator.global_scope.deinit();
        translator.needed_builtins.deinit(gpa);
        translator.needed_helpers.deinit(gpa);
    }

    try translator.prepopulateGlobalNameTable();
    try translator.transTopLevelDecls();
    try translator.transMacros();

    for (translator.alias_list.items) |alias| {
        if (!translator.global_scope.sym_table.contains(alias.alias)) {
            const node = try ZigTag.alias.create(arena, .{ .actual = alias.alias, .mangled = alias.name });
            try translator.addTopLevelDecl(alias.alias, node);
        }
    }

    var buf: std.ArrayList(u8) = .init(gpa);
    defer buf.deinit();

    for (translator.needed_builtins.values()) |source| {
        try buf.appendSlice(source);
    }

    if (translator.needed_helpers.entries.len > 0) {
        if (buf.items.len != 0) try buf.append('\n');

        try buf.appendSlice("pub const __helpers = struct {\n");
        for (translator.needed_helpers.values(), 0..) |source, i| {
            if (i != 0) try buf.append('\n');

            // Properly indent the functions.
            var it = std.mem.splitScalar(u8, source, '\n');
            while (it.next()) |line| {
                if (line.len != 0) try buf.appendSlice("    ");
                try buf.appendSlice(line);
                if (it.rest().len != 0) try buf.append('\n');
            }
        }
        try buf.appendSlice("\n};\n\n");
    }

    var zig_ast = try ast.render(gpa, translator.global_scope.nodes.items);
    defer {
        gpa.free(zig_ast.source);
        zig_ast.deinit(gpa);
    }
    try zig_ast.renderToArrayList(&buf, .{});
    return buf.toOwnedSlice();
}

fn prepopulateGlobalNameTable(t: *Translator) !void {
    for (t.tree.root_decls.items) |decl| {
        switch (decl.get(t.tree)) {
            .typedef => |typedef_decl| {
                const decl_name = t.tree.tokSlice(typedef_decl.name_tok);
                try t.global_names.put(t.gpa, decl_name, {});

                // Check for typedefs with unnamed enum/record child types.
                const base = typedef_decl.qt.base(t.comp);
                switch (base.type) {
                    .@"enum" => |enum_ty| {
                        if (enum_ty.name.lookup(t.comp)[0] != '(') continue;
                    },
                    .@"struct", .@"union" => |record_ty| {
                        if (record_ty.name.lookup(t.comp)[0] != '(') continue;
                    },
                    else => continue,
                }

                const gop = try t.unnamed_typedefs.getOrPut(t.gpa, base.qt);
                if (gop.found_existing) {
                    // One typedef can declare multiple names.
                    // TODO Don't put this one in `decl_table` so it's processed later.
                    continue;
                }
                gop.value_ptr.* = decl_name;
            },

            .struct_decl,
            .union_decl,
            .struct_forward_decl,
            .union_forward_decl,
            .enum_decl,
            .enum_forward_decl,
            => {
                const decl_qt = decl.qt(t.tree);
                const prefix, const name = switch (decl_qt.base(t.comp).type) {
                    .@"struct" => |struct_ty| .{ "struct", struct_ty.name.lookup(t.comp) },
                    .@"union" => |union_ty| .{ "union", union_ty.name.lookup(t.comp) },
                    .@"enum" => |enum_ty| .{ "enum", enum_ty.name.lookup(t.comp) },
                    else => unreachable,
                };
                const prefixed_name = try std.fmt.allocPrint(t.arena, "{s}_{s}", .{ prefix, name });
                // `name` and `prefixed_name` are the preferred names for this type.
                // However, we can name it anything else if necessary, so these are "weak names".
                try t.weak_global_names.ensureUnusedCapacity(t.gpa, 2);
                t.weak_global_names.putAssumeCapacity(name, {});
                t.weak_global_names.putAssumeCapacity(prefixed_name, {});
            },

            .fn_proto,
            .fn_def,
            .variable,
            => {
                const decl_name = t.tree.tokSlice(decl.tok(t.tree));
                try t.global_names.put(t.gpa, decl_name, {});
            },
            .static_assert => {},
            .empty_decl => {},
            else => unreachable,
        }
    }
}

// =======================
// Declaration translation
// =======================

fn transTopLevelDecls(t: *Translator) !void {
    for (t.tree.root_decls.items) |decl| {
        try t.transDecl(&t.global_scope.base, decl);
    }
}

fn transDecl(t: *Translator, scope: *Scope, decl: Node.Index) !void {
    switch (decl.get(t.tree)) {
        .typedef => |typedef_decl| {
            // Implicit typedefs are translated only if referenced.
            if (typedef_decl.implicit) return;
            try t.transTypeDef(scope, decl);
        },

        .struct_decl, .union_decl => |record_decl| {
            try t.transRecordDecl(scope, record_decl.container_qt);
        },

        .enum_decl => |enum_decl| {
            try t.transEnumDecl(scope, enum_decl.container_qt);
        },

        .enum_field,
        .record_field,
        .struct_forward_decl,
        .union_forward_decl,
        .enum_forward_decl,
        => return,

        .fn_proto, .fn_def => {
            try t.transFnDecl(scope, decl);
        },

        .variable => |variable| {
            try t.transVarDecl(scope, variable);
        },
        .static_assert => |static_assert| {
            try t.transStaticAssert(&t.global_scope.base, static_assert);
        },
        .empty_decl => {},
        else => unreachable,
    }
}

const builtin_typedef_map = std.StaticStringMap([]const u8).initComptime(.{
    .{ "uint8_t", "u8" },
    .{ "int8_t", "i8" },
    .{ "uint16_t", "u16" },
    .{ "int16_t", "i16" },
    .{ "uint32_t", "u32" },
    .{ "int32_t", "i32" },
    .{ "uint64_t", "u64" },
    .{ "int64_t", "i64" },
    .{ "intptr_t", "isize" },
    .{ "uintptr_t", "usize" },
    .{ "ssize_t", "isize" },
    .{ "size_t", "usize" },
});

fn transTypeDef(t: *Translator, scope: *Scope, typedef_node: Node.Index) Error!void {
    const typedef_decl = typedef_node.get(t.tree).typedef;
    if (t.type_decls.get(typedef_node)) |_|
        return; // Avoid processing this decl twice

    const toplevel = scope.id == .root;
    const bs: *Scope.Block = if (!toplevel) try scope.findBlockScope(t) else undefined;

    var name: []const u8 = t.tree.tokSlice(typedef_decl.name_tok);
    try t.typedefs.put(t.gpa, name, {});

    if (builtin_typedef_map.get(name)) |builtin| {
        return t.type_decls.putNoClobber(t.gpa, typedef_node, builtin);
    }
    if (!toplevel) name = try bs.makeMangledName(name);
    try t.type_decls.putNoClobber(t.gpa, typedef_node, name);

    const typedef_loc = typedef_decl.name_tok;
    const init_node = t.transType(scope, typedef_decl.qt, typedef_loc) catch |err| switch (err) {
        error.UnsupportedType => {
            return t.failDecl(typedef_loc, name, "unable to resolve typedef child type", .{});
        },
        error.OutOfMemory => |e| return e,
    };

    const payload = try t.arena.create(ast.Payload.SimpleVarDecl);
    payload.* = .{
        .base = .{ .tag = if (toplevel) .pub_var_simple else .var_simple },
        .data = .{
            .name = name,
            .init = init_node,
        },
    };
    const node = ZigNode.initPayload(&payload.base);

    if (toplevel) {
        try t.addTopLevelDecl(name, node);
    } else {
        try scope.appendNode(node);
        try bs.discardVariable(name);
    }
}

fn mangleWeakGlobalName(t: *Translator, want_name: []const u8) Error![]const u8 {
    var cur_name = want_name;

    if (!t.weak_global_names.contains(want_name)) {
        // This type wasn't noticed by the name detection pass, so nothing has been treating this as
        // a weak global name. We must mangle it to avoid conflicts with locals.
        cur_name = try std.fmt.allocPrint(t.arena, "{s}_{d}", .{ want_name, t.getMangle() });
    }

    while (t.global_names.contains(cur_name)) {
        cur_name = try std.fmt.allocPrint(t.arena, "{s}_{d}", .{ want_name, t.getMangle() });
    }
    return cur_name;
}

fn transRecordDecl(t: *Translator, scope: *Scope, record_qt: QualType) Error!void {
    const base = record_qt.base(t.comp);
    const record_ty = switch (base.type) {
        .@"struct", .@"union" => |record_ty| record_ty,
        else => unreachable,
    };

    if (t.type_decls.get(record_ty.decl_node)) |_|
        return; // Avoid processing this decl twice

    const toplevel = scope.id == .root;
    const bs: *Scope.Block = if (!toplevel) try scope.findBlockScope(t) else undefined;

    const container_kind: ZigTag = if (base.type == .@"union") .@"union" else .@"struct";
    const container_kind_name = @tagName(container_kind);

    var bare_name = record_ty.name.lookup(t.comp);
    var is_unnamed = false;
    var name = bare_name;

    if (t.unnamed_typedefs.get(base.qt)) |typedef_name| {
        bare_name = typedef_name;
        name = typedef_name;
    } else {
        if (record_ty.isAnonymous(t.comp)) {
            bare_name = try std.fmt.allocPrint(t.arena, "unnamed_{d}", .{t.getMangle()});
            is_unnamed = true;
        }
        name = try std.fmt.allocPrint(t.arena, "{s}_{s}", .{ container_kind_name, bare_name });
        if (toplevel and !is_unnamed) {
            name = try t.mangleWeakGlobalName(name);
        }
    }
    if (!toplevel) name = try bs.makeMangledName(name);
    try t.type_decls.putNoClobber(t.gpa, record_ty.decl_node, name);

    const is_pub = toplevel and !is_unnamed;
    const init_node = init: {
        if (record_ty.layout == null) {
            try t.opaque_demotes.put(t.gpa, base.qt, {});
            break :init ZigTag.opaque_literal.init();
        }

        var fields = try std.ArrayList(ast.Payload.Record.Field).initCapacity(t.gpa, record_ty.fields.len);
        defer fields.deinit();

        // TODO: Add support for flexible array field functions
        var functions = std.ArrayList(ZigNode).init(t.gpa);
        defer functions.deinit();

        var unnamed_field_count: u32 = 0;

        // If a record doesn't have any attributes that would affect the alignment and
        // layout, then we can just use a simple `extern` type. If it does have attributes,
        // then we need to inspect the layout and assign an `align` value for each field.
        const has_alignment_attributes = aligned: {
            if (record_qt.hasAttribute(t.comp, .@"packed")) break :aligned true;
            if (record_qt.hasAttribute(t.comp, .aligned)) break :aligned true;
            for (record_ty.fields) |field| {
                const field_attrs = field.attributes(t.comp);
                for (field_attrs) |field_attr| {
                    switch (field_attr.tag) {
                        .@"packed", .aligned => break :aligned true,
                        else => {},
                    }
                }
            }
            break :aligned false;
        };
        const head_field_alignment: ?c_uint = if (has_alignment_attributes) t.headFieldAlignment(record_ty) else null;

        for (record_ty.fields, 0..) |field, field_index| {
            const field_loc = field.name_tok;

            // Demote record to opaque if it contains a bitfield
            if (field.bit_width != .null) {
                try t.opaque_demotes.put(t.gpa, base.qt, {});
                try t.warn(scope, field_loc, "{s} demoted to opaque type - has bitfield", .{container_kind_name});
                break :init ZigTag.opaque_literal.init();
            }

            var field_name = field.name.lookup(t.comp);
            if (field.name_tok == 0) {
                field_name = try std.fmt.allocPrint(t.arena, "unnamed_{d}", .{unnamed_field_count});
                unnamed_field_count += 1;
                try t.anonymous_record_field_names.put(t.gpa, .{
                    .parent = base.qt,
                    .field = field.qt,
                }, field_name);
            }
            const field_type = t.transType(scope, field.qt, field_loc) catch |err| switch (err) {
                error.UnsupportedType => {
                    try t.opaque_demotes.put(t.gpa, base.qt, {});
                    try t.warn(scope, field.name_tok, "{s} demoted to opaque type - unable to translate type of field {s}", .{
                        container_kind_name,
                        field_name,
                    });
                    break :init ZigTag.opaque_literal.init();
                },
                else => |e| return e,
            };

            const field_alignment = if (has_alignment_attributes)
                t.alignmentForField(record_ty, head_field_alignment, field_index)
            else
                null;

            // C99 introduced designated initializers for structs. Omitted fields are implicitly
            // initialized to zero. Some C APIs are designed with this in mind. Defaulting to zero
            // values for translated struct fields permits Zig code to comfortably use such an API.
            const default_value = if (container_kind == .@"struct")
                try t.createZeroValueNode(field.qt, field_type, .no_as)
            else
                null;

            fields.appendAssumeCapacity(.{
                .name = field_name,
                .type = field_type,
                .alignment = field_alignment,
                .default_value = default_value,
            });
        }

        const record_payload = try t.arena.create(ast.Payload.Record);
        record_payload.* = .{
            .base = .{ .tag = container_kind },
            .data = .{
                .layout = .@"extern",
                .fields = try t.arena.dupe(ast.Payload.Record.Field, fields.items),
                .functions = try t.arena.dupe(ZigNode, functions.items),
                .variables = &.{},
            },
        };
        break :init ZigNode.initPayload(&record_payload.base);
    };

    const payload = try t.arena.create(ast.Payload.SimpleVarDecl);
    payload.* = .{
        .base = .{ .tag = if (is_pub) .pub_var_simple else .var_simple },
        .data = .{
            .name = name,
            .init = init_node,
        },
    };
    const node = ZigNode.initPayload(&payload.base);
    if (toplevel) {
        try t.addTopLevelDecl(name, node);
        // Only add the alias if the name is available *and* it was caught by
        // name detection. Don't bother performing a weak mangle, since a
        // mangled name is of no real use here.
        if (!is_unnamed and !t.global_names.contains(bare_name) and t.weak_global_names.contains(bare_name))
            try t.alias_list.append(t.gpa, .{ .alias = bare_name, .name = name });
    } else {
        try scope.appendNode(node);
        try bs.discardVariable(name);
    }
}

fn transFnDecl(t: *Translator, scope: *Scope, fn_decl_node: Node.Index) Error!void {
    const raw_qt = fn_decl_node.qt(t.tree);
    const func_ty = raw_qt.get(t.comp, .func).?;
    const name_tok: TokenIndex, const body_node: ?Node.Index, const is_export_or_inline = switch (fn_decl_node.get(t.tree)) {
        .fn_def => |fn_def| .{ fn_def.name_tok, fn_def.body, fn_def.@"inline" or fn_def.static },
        .fn_proto => |fn_proto| .{ fn_proto.name_tok, null, fn_proto.@"inline" or fn_proto.static },
        else => unreachable,
    };

    const is_pub = scope.id == .root;

    // TODO if this is a prototype for which a definition exists,
    // that definition should be translated instead.
    const fn_name = t.tree.tokSlice(name_tok);
    if (t.global_scope.sym_table.contains(fn_name))
        return; // Avoid processing this decl twice

    const fn_decl_loc = name_tok;
    const has_body = body_node != null;
    const is_always_inline = has_body and raw_qt.getAttribute(t.comp, .always_inline) != null;
    const proto_ctx: FnProtoContext = .{
        .fn_name = fn_name,
        .is_always_inline = is_always_inline,
        .is_extern = !has_body,
        .is_export = !is_export_or_inline and has_body and !is_always_inline,
        .is_pub = is_pub,
        .cc = if (raw_qt.getAttribute(t.comp, .calling_convention)) |some| switch (some.cc) {
            .C => .c,
            .stdcall => .x86_stdcall,
            .thiscall => .x86_thiscall,
            .vectorcall => switch (t.comp.target.cpu.arch) {
                .x86 => .x86_vectorcall,
                .aarch64, .aarch64_be => .aarch64_vfabi,
                else => .c,
            },
        } else .c,
    };

    const proto_node = t.transFnType(&t.global_scope.base, raw_qt, func_ty, fn_decl_loc, proto_ctx) catch |err| switch (err) {
        error.UnsupportedType => {
            return t.failDecl(fn_decl_loc, fn_name, "unable to resolve prototype of function", .{});
        },
        error.OutOfMemory => |e| return e,
    };

    if (!has_body) {
        if (scope.id != .root) {
            const bs: *Scope.Block = try scope.findBlockScope(t);
            const mangled_name = try bs.createMangledName(fn_name, false, Scope.Block.extern_local_prefix);
            const wrapped = try ZigTag.wrapped_local.create(t.arena, .{ .name = mangled_name, .init = proto_node });
            try scope.appendNode(wrapped);
            try bs.discardVariable(mangled_name);
            return;
        }
        return t.addTopLevelDecl(fn_name, proto_node);
    }
    const proto_payload = proto_node.castTag(.func).?;

    // actual function definition with body
    const body_stmt = body_node.?.get(t.tree).compound_stmt;
    var block_scope = try Scope.Block.init(t, &t.global_scope.base, false);
    block_scope.return_type = func_ty.return_type;
    defer block_scope.deinit();

    var param_id: c_uint = 0;
    for (proto_payload.data.params, func_ty.params) |*param, param_info| {
        const param_name = param.name orelse {
            proto_payload.data.is_extern = true;
            proto_payload.data.is_export = false;
            proto_payload.data.is_inline = false;
            try t.warn(&t.global_scope.base, fn_decl_loc, "function {s} parameter has no name, demoted to extern", .{fn_name});
            return t.addTopLevelDecl(fn_name, proto_node);
        };

        const is_const = param_info.qt.@"const";

        const mangled_param_name = try block_scope.makeMangledName(param_name);
        param.name = mangled_param_name;

        if (!is_const) {
            const bare_arg_name = try std.fmt.allocPrint(t.arena, "arg_{s}", .{mangled_param_name});
            const arg_name = try block_scope.makeMangledName(bare_arg_name);
            param.name = arg_name;

            const redecl_node = try ZigTag.arg_redecl.create(t.arena, .{ .actual = mangled_param_name, .mangled = arg_name });
            try block_scope.statements.append(t.gpa, redecl_node);
        }
        try block_scope.discardVariable(mangled_param_name);

        param_id += 1;
    }

    t.transCompoundStmtInline(body_stmt, &block_scope) catch |err| switch (err) {
        error.OutOfMemory => |e| return e,
        error.UnsupportedTranslation,
        error.UnsupportedType,
        => {
            proto_payload.data.is_extern = true;
            proto_payload.data.is_export = false;
            proto_payload.data.is_inline = false;
            try t.warn(&t.global_scope.base, fn_decl_loc, "unable to translate function, demoted to extern", .{});
            return t.addTopLevelDecl(fn_name, proto_node);
        },
    };

    proto_payload.data.body = try block_scope.complete();
    return t.addTopLevelDecl(fn_name, proto_node);
}

fn transVarDecl(t: *Translator, scope: *Scope, variable: Node.Variable) Error!void {
    const base_name = t.tree.tokSlice(variable.name_tok);
    const toplevel = scope.id == .root;
    const bs: *Scope.Block = if (!toplevel) try scope.findBlockScope(t) else undefined;
    const name, const use_base_name = blk: {
        if (toplevel) break :blk .{ base_name, false };

        // Local extern and static variables are wrapped in a struct.
        const prefix: ?[]const u8 = switch (variable.storage_class) {
            .@"extern" => Scope.Block.extern_local_prefix,
            .static => Scope.Block.static_local_prefix,
            else => null,
        };
        break :blk .{ try bs.createMangledName(base_name, false, prefix), prefix != null };
    };

    if (t.typeWasDemotedToOpaque(variable.qt)) {
        if (variable.storage_class != .@"extern") {
            return t.failDecl(variable.name_tok, name, "non-extern variable has opaque type", .{});
        } else {
            return t.failDecl(variable.name_tok, name, "local variable has opaque type", .{});
        }
    }

    const type_node = t.transType(scope, variable.qt, variable.name_tok) catch |err| switch (err) {
        error.UnsupportedType => {
            return t.failDecl(variable.name_tok, name, "unable to translate variable declaration type", .{});
        },
        else => |e| return e,
    };

    const init_node = init: {
        if (variable.initializer) |init| {
            const init_node = t.transExprCoercing(scope, init, .used) catch |err| switch (err) {
                error.UnsupportedTranslation, error.UnsupportedType => {
                    return t.failDecl(variable.name_tok, name, "unable to resolve var init expr", .{});
                },
                else => |e| return e,
            };

            if (!variable.qt.is(t.comp, .bool) and init_node.isBoolRes()) {
                break :init try ZigTag.int_from_bool.create(t.arena, init_node);
            } else {
                break :init init_node;
            }
        }
        if (variable.storage_class == .@"extern") break :init null;
        if (toplevel or variable.storage_class == .static or variable.thread_local) {
            // The C language specification states that variables with static or threadlocal
            // storage without an initializer are initialized to a zero value.
            break :init try t.createZeroValueNode(variable.qt, type_node, .no_as);
        }
        break :init ZigTag.undefined_literal.init();
    };

    const alignment: ?c_uint = variable.qt.requestedAlignment(t.comp) orelse null;
    var node = try ZigTag.var_decl.create(t.arena, .{
        .is_pub = toplevel,
        .is_const = variable.qt.@"const",
        .is_extern = variable.storage_class == .@"extern",
        .is_export = toplevel and variable.storage_class == .auto,
        .is_threadlocal = variable.thread_local,
        .linksection_string = null,
        .alignment = alignment,
        .name = if (use_base_name) base_name else name,
        .type = type_node,
        .init = init_node,
    });

    if (toplevel) {
        try t.addTopLevelDecl(name, node);
    } else {
        if (use_base_name) {
            node = try ZigTag.wrapped_local.create(t.arena, .{ .name = name, .init = node });
        }
        try scope.appendNode(node);
        try bs.discardVariable(name);
    }
}

fn transEnumDecl(t: *Translator, scope: *Scope, enum_qt: QualType) Error!void {
    const base = enum_qt.base(t.comp);
    const enum_ty = base.type.@"enum";

    if (t.type_decls.get(enum_ty.decl_node)) |_|
        return; // Avoid processing this decl twice

    const toplevel = scope.id == .root;
    const bs: *Scope.Block = if (!toplevel) try scope.findBlockScope(t) else undefined;

    var bare_name = enum_ty.name.lookup(t.comp);
    var is_unnamed = false;
    var name = bare_name;
    if (t.unnamed_typedefs.get(base.qt)) |typedef_name| {
        bare_name = typedef_name;
        name = typedef_name;
    } else {
        if (enum_ty.isAnonymous(t.comp)) {
            bare_name = try std.fmt.allocPrint(t.arena, "unnamed_{d}", .{t.getMangle()});
            is_unnamed = true;
        }
        name = try std.fmt.allocPrint(t.arena, "enum_{s}", .{bare_name});
    }
    if (!toplevel) name = try bs.makeMangledName(name);
    try t.type_decls.putNoClobber(t.gpa, enum_ty.decl_node, name);

    const enum_type_node = if (!base.qt.hasIncompleteSize(t.comp)) blk: {
        const enum_decl = enum_ty.decl_node.get(t.tree).enum_decl;
        for (enum_ty.fields, enum_decl.fields) |field, field_node| {
            var enum_val_name = field.name.lookup(t.comp);
            if (!toplevel) {
                enum_val_name = try bs.makeMangledName(enum_val_name);
            }

            const enum_const_type_node: ?ZigNode = t.transType(scope, field.qt, field.name_tok) catch |err| switch (err) {
                error.UnsupportedType => null,
                else => |e| return e,
            };

            const val = t.tree.value_map.get(field_node).?;
            const enum_const_def = try ZigTag.enum_constant.create(t.arena, .{
                .name = enum_val_name,
                .is_public = toplevel,
                .type = enum_const_type_node,
                .value = try t.createIntNode(val),
            });
            if (toplevel)
                try t.addTopLevelDecl(enum_val_name, enum_const_def)
            else {
                try scope.appendNode(enum_const_def);
                try bs.discardVariable(enum_val_name);
            }
        }

        break :blk t.transType(scope, enum_ty.tag.?, enum_decl.name_or_kind_tok) catch |err| switch (err) {
            error.UnsupportedType => {
                return t.failDecl(enum_decl.name_or_kind_tok, name, "unable to translate enum integer type", .{});
            },
            else => |e| return e,
        };
    } else blk: {
        try t.opaque_demotes.put(t.gpa, base.qt, {});
        break :blk ZigTag.opaque_literal.init();
    };

    const is_pub = toplevel and !is_unnamed;
    const payload = try t.arena.create(ast.Payload.SimpleVarDecl);
    payload.* = .{
        .base = .{ .tag = if (is_pub) .pub_var_simple else .var_simple },
        .data = .{
            .init = enum_type_node,
            .name = name,
        },
    };
    const node = ZigNode.initPayload(&payload.base);
    if (toplevel) {
        try t.addTopLevelDecl(name, node);
        if (!is_unnamed)
            try t.alias_list.append(t.gpa, .{ .alias = bare_name, .name = name });
    } else {
        try scope.appendNode(node);
        try bs.discardVariable(name);
    }
}

fn transStaticAssert(t: *Translator, scope: *Scope, static_assert: Node.StaticAssert) Error!void {
    const condition = t.transExpr(scope, static_assert.cond, .used) catch |err| switch (err) {
        error.UnsupportedTranslation, error.UnsupportedType => {
            return try t.warn(&t.global_scope.base, static_assert.cond.tok(t.tree), "unable to translate _Static_assert condition", .{});
        },
        error.OutOfMemory => |e| return e,
    };

    // generate @compileError message that matches C compiler output
    const diagnostic = if (static_assert.message) |message| str: {
        // Aro guarantees this to be a string literal.
        const str_val = t.tree.value_map.get(message).?;
        const str_qt = message.qt(t.tree);

        const bytes = t.comp.interner.get(str_val.ref()).bytes;
        var buf = std.ArrayList(u8).init(t.gpa);
        defer buf.deinit();

        try buf.appendSlice("\"static assertion failed \\");

        try buf.ensureUnusedCapacity(bytes.len);
        try aro.Value.printString(bytes, str_qt, t.comp, buf.writer());
        _ = buf.pop(); // printString adds a terminating " so we need to remove it
        try buf.appendSlice("\\\"\"");

        break :str try ZigTag.string_literal.create(t.arena, try t.arena.dupe(u8, buf.items));
    } else try ZigTag.string_literal.create(t.arena, "\"static assertion failed\"");

    const assert_node = try ZigTag.static_assert.create(t.arena, .{ .lhs = condition, .rhs = diagnostic });
    try scope.appendNode(assert_node);
}

// ================
// Type translation
// ================

fn getTypeStr(t: *Translator, qt: QualType) ![]const u8 {
    var buf: std.ArrayListUnmanaged(u8) = .empty;
    defer buf.deinit(t.gpa);
    const w = buf.writer(t.gpa);
    try qt.print(t.comp, w);
    return t.arena.dupe(u8, buf.items);
}

fn transType(t: *Translator, scope: *Scope, qt: QualType, source_loc: TokenIndex) TypeError!ZigNode {
    loop: switch (qt.type(t.comp)) {
        .atomic => {
            const type_name = try t.getTypeStr(qt);
            return t.fail(error.UnsupportedType, source_loc, "TODO support atomic type: '{s}'", .{type_name});
        },
        .void => return ZigTag.type.create(t.arena, "anyopaque"),
        .bool => return ZigTag.type.create(t.arena, "bool"),
        .int => |int_ty| switch (int_ty) {
            //.char => return ZigTag.type.create(t.arena, "c_char"), // TODO: this is the preferred translation
            .char => return ZigTag.type.create(t.arena, "u8"),
            .schar => return ZigTag.type.create(t.arena, "i8"),
            .uchar => return ZigTag.type.create(t.arena, "u8"),
            .short => return ZigTag.type.create(t.arena, "c_short"),
            .ushort => return ZigTag.type.create(t.arena, "c_ushort"),
            .int => return ZigTag.type.create(t.arena, "c_int"),
            .uint => return ZigTag.type.create(t.arena, "c_uint"),
            .long => return ZigTag.type.create(t.arena, "c_long"),
            .ulong => return ZigTag.type.create(t.arena, "c_ulong"),
            .long_long => return ZigTag.type.create(t.arena, "c_longlong"),
            .ulong_long => return ZigTag.type.create(t.arena, "c_ulonglong"),
            .int128 => return ZigTag.type.create(t.arena, "i128"),
            .uint128 => return ZigTag.type.create(t.arena, "u128"),
        },
        .float => |float_ty| switch (float_ty) {
            .fp16, .float16 => return ZigTag.type.create(t.arena, "f16"),
            .float => return ZigTag.type.create(t.arena, "f32"),
            .double => return ZigTag.type.create(t.arena, "f64"),
            .long_double => return ZigTag.type.create(t.arena, "c_longdouble"),
            .float128 => return ZigTag.type.create(t.arena, "f128"),
        },
        .pointer => |pointer_ty| {
            const child_qt = pointer_ty.child;

            const is_fn_proto = child_qt.is(t.comp, .func);
            const is_const = is_fn_proto or child_qt.@"const";
            const is_volatile = child_qt.@"volatile";
            const elem_type = try t.transType(scope, child_qt, source_loc);
            const ptr_info: @FieldType(ast.Payload.Pointer, "data") = .{
                .is_const = is_const,
                .is_volatile = is_volatile,
                .elem_type = elem_type,
            };
            if (is_fn_proto or
                t.typeIsOpaque(child_qt) or
                t.typeWasDemotedToOpaque(child_qt))
            {
                const ptr = try ZigTag.single_pointer.create(t.arena, ptr_info);
                return ZigTag.optional_type.create(t.arena, ptr);
            }

            return ZigTag.c_pointer.create(t.arena, ptr_info);
        },
        .array => |array_ty| {
            const elem_qt = array_ty.elem;
            switch (array_ty.len) {
                .incomplete, .unspecified_variable => {
                    const elem_type = try t.transType(scope, elem_qt, source_loc);
                    return ZigTag.c_pointer.create(t.arena, .{ .is_const = elem_qt.@"const", .is_volatile = elem_qt.@"volatile", .elem_type = elem_type });
                },
                .fixed, .static => |len| {
                    const elem_type = try t.transType(scope, elem_qt, source_loc);
                    return ZigTag.array_type.create(t.arena, .{ .len = len, .elem_type = elem_type });
                },
                .variable => return t.fail(error.UnsupportedType, source_loc, "VLA unsupported '{s}'", .{try t.getTypeStr(qt)}),
            }
        },
        .func => |func_ty| return t.transFnType(scope, qt, func_ty, source_loc, .{}),
        .@"struct", .@"union" => |record_ty| {
            var trans_scope = scope;
            if (record_ty.isAnonymous(t.comp)) {
                if (t.weak_global_names.contains(record_ty.name.lookup(t.comp))) trans_scope = &t.global_scope.base;
            }
            try t.transRecordDecl(trans_scope, qt);
            const name = t.type_decls.get(record_ty.decl_node).?;
            return ZigTag.identifier.create(t.arena, name);
        },
        .@"enum" => |enum_ty| {
            var trans_scope = scope;
            const is_anonymous = enum_ty.isAnonymous(t.comp);
            if (is_anonymous) {
                if (t.weak_global_names.contains(enum_ty.name.lookup(t.comp))) trans_scope = &t.global_scope.base;
            }
            try t.transEnumDecl(trans_scope, qt);
            const name = t.type_decls.get(enum_ty.decl_node).?;
            return ZigTag.identifier.create(t.arena, name);
        },
        .typedef => |typedef_ty| {
            var trans_scope = scope;
            const typedef_name = typedef_ty.name.lookup(t.comp);
            if (builtin_typedef_map.get(typedef_name)) |builtin| return ZigTag.type.create(t.arena, builtin);
            if (t.global_names.contains(typedef_name)) trans_scope = &t.global_scope.base;

            try t.transTypeDef(trans_scope, typedef_ty.decl_node);
            const name = t.type_decls.get(typedef_ty.decl_node).?;
            return ZigTag.identifier.create(t.arena, name);
        },
        .attributed => |attributed_ty| continue :loop attributed_ty.base.type(t.comp),
        .typeof => |typeof_ty| continue :loop typeof_ty.base.type(t.comp),
        else => return t.fail(error.UnsupportedType, source_loc, "unsupported type: '{s}'", .{try t.getTypeStr(qt)}),
    }
}

/// Look ahead through the fields of the record to determine what the alignment of the record
/// would be without any align/packed/etc. attributes. This helps us determine whether or not
/// the fields with 0 offset need an `align` qualifier. Strictly speaking, we could just
/// pedantically assign those fields the same alignment as the parent's pointer alignment,
/// but this helps the generated code to be a little less verbose.
fn headFieldAlignment(t: *Translator, record_decl: aro.Type.Record) ?c_uint {
    const bits_per_byte = 8;
    const parent_ptr_alignment_bits = record_decl.layout.?.pointer_alignment_bits;
    const parent_ptr_alignment = parent_ptr_alignment_bits / bits_per_byte;
    var max_field_alignment_bits: u64 = 0;
    for (record_decl.fields) |field| {
        if (field.qt.getRecord(t.comp)) |field_record_decl| {
            const child_record_alignment = field_record_decl.layout.?.field_alignment_bits;
            if (child_record_alignment > max_field_alignment_bits)
                max_field_alignment_bits = child_record_alignment;
        } else {
            const field_size = field.layout.size_bits;
            if (field_size > max_field_alignment_bits)
                max_field_alignment_bits = field_size;
        }
    }
    if (max_field_alignment_bits != parent_ptr_alignment_bits) {
        return parent_ptr_alignment;
    } else {
        return null;
    }
}

/// This function inspects the generated layout of a record to determine the alignment for a
/// particular field. This approach is necessary because unlike Zig, a C compiler is not
/// required to fulfill the requested alignment, which means we'd risk generating different code
/// if we only look at the user-requested alignment.
///
/// Returns a ?c_uint to match Clang's behavior of using c_uint. The return type can be changed
/// after the Clang frontend for translate-c is removed. A null value indicates that a field is
/// 'naturally aligned'.
fn alignmentForField(
    t: *Translator,
    record_decl: aro.Type.Record,
    head_field_alignment: ?c_uint,
    field_index: usize,
) ?c_uint {
    const fields = record_decl.fields;
    assert(fields.len != 0);
    const field = fields[field_index];

    const bits_per_byte = 8;
    const parent_ptr_alignment_bits = record_decl.layout.?.pointer_alignment_bits;
    const parent_ptr_alignment = parent_ptr_alignment_bits / bits_per_byte;

    // bitfields aren't supported yet. Until support is added, records with bitfields
    // should be demoted to opaque, and this function shouldn't be called for them.
    if (field.bit_width != .null) {
        @panic("TODO: add bitfield support for records");
    }

    const field_offset_bits: u64 = field.layout.offset_bits;
    const field_size_bits: u64 = field.layout.size_bits;

    // Fields with zero width always have an alignment of 1
    if (field_size_bits == 0) {
        return 1;
    }

    // Fields with 0 offset inherit the parent's pointer alignment.
    if (field_offset_bits == 0) {
        return head_field_alignment;
    }

    // Records have a natural alignment when used as a field, and their size is
    // a multiple of this alignment value. For all other types, the natural alignment
    // is their size.
    const field_natural_alignment_bits: u64 = if (field.qt.getRecord(t.comp)) |record|
        record.layout.?.field_alignment_bits
    else
        field_size_bits;
    const rem_bits = field_offset_bits % field_natural_alignment_bits;

    // If there's a remainder, then the alignment is smaller than the field's
    // natural alignment
    if (rem_bits > 0) {
        const rem_alignment = rem_bits / bits_per_byte;
        if (rem_alignment > 0 and std.math.isPowerOfTwo(rem_alignment)) {
            const actual_alignment = @min(rem_alignment, parent_ptr_alignment);
            return @as(c_uint, @truncate(actual_alignment));
        } else {
            return 1;
        }
    }

    // A field may have an offset which positions it to be naturally aligned, but the
    // parent's pointer alignment determines if this is actually true, so we take the minimum
    // value.
    // For example, a float field (4 bytes wide) with a 4 byte offset is positioned to have natural
    // alignment, but if the parent pointer alignment is 2, then the actual alignment of the
    // float is 2.
    const field_natural_alignment: u64 = field_natural_alignment_bits / bits_per_byte;
    const offset_alignment = field_offset_bits / bits_per_byte;
    const possible_alignment = @min(parent_ptr_alignment, offset_alignment);
    if (possible_alignment == field_natural_alignment) {
        return null;
    } else if (possible_alignment < field_natural_alignment) {
        if (std.math.isPowerOfTwo(possible_alignment)) {
            return possible_alignment;
        } else {
            return 1;
        }
    } else { // possible_alignment > field_natural_alignment
        // Here, the field is positioned be at a higher alignment than it's natural alignment. This means we
        // need to determine whether it's a specified alignment. We can determine that from the padding preceding
        // the field.
        const padding_from_prev_field: u64 = blk: {
            if (field_offset_bits != 0) {
                const previous_field = fields[field_index - 1];
                break :blk (field_offset_bits - previous_field.layout.offset_bits) - previous_field.layout.size_bits;
            } else {
                break :blk 0;
            }
        };
        if (padding_from_prev_field < field_natural_alignment_bits) {
            return null;
        } else {
            return possible_alignment;
        }
    }
}

const FnProtoContext = struct {
    is_pub: bool = false,
    is_export: bool = false,
    is_extern: bool = false,
    is_always_inline: bool = false,
    fn_name: ?[]const u8 = null,
    cc: ast.Payload.Func.CallingConvention = .c,
};

fn transFnType(
    t: *Translator,
    scope: *Scope,
    func_qt: QualType,
    func_ty: aro.Type.Func,
    source_loc: TokenIndex,
    ctx: FnProtoContext,
) !ZigNode {
    const param_count: usize = func_ty.params.len;
    const fn_params = try t.arena.alloc(ast.Payload.Param, param_count);

    for (func_ty.params, fn_params) |param_info, *param_node| {
        const param_qt = param_info.qt;
        const is_noalias = param_qt.restrict;

        const param_name: ?[]const u8 = if (param_info.name == .empty)
            null
        else
            param_info.name.lookup(t.comp);

        const type_node = try t.transType(scope, param_qt, param_info.name_tok);
        param_node.* = .{
            .is_noalias = is_noalias,
            .name = param_name,
            .type = type_node,
        };
    }

    const linksection_string = blk: {
        if (func_qt.getAttribute(t.comp, .section)) |section| {
            break :blk t.comp.interner.get(section.name.ref()).bytes;
        }
        break :blk null;
    };

    const alignment: ?c_uint = func_qt.requestedAlignment(t.comp) orelse null;

    const explicit_callconv = if ((ctx.is_always_inline or ctx.is_export or ctx.is_extern) and ctx.cc == .c) null else ctx.cc;

    const return_type_node = blk: {
        if (func_qt.getAttribute(t.comp, .noreturn) != null) {
            break :blk ZigTag.noreturn_type.init();
        } else {
            const return_qt = func_ty.return_type;
            if (return_qt.is(t.comp, .void)) {
                // convert primitive anyopaque to actual void (only for return type)
                break :blk ZigTag.void_type.init();
            } else {
                break :blk t.transType(scope, return_qt, source_loc) catch |err| switch (err) {
                    error.UnsupportedType => {
                        try t.warn(scope, source_loc, "unsupported function proto return type", .{});
                        return err;
                    },
                    error.OutOfMemory => |e| return e,
                };
            }
        }
    };

    const payload = try t.arena.create(ast.Payload.Func);
    payload.* = .{
        .base = .{ .tag = .func },
        .data = .{
            .is_pub = ctx.is_pub,
            .is_extern = ctx.is_extern,
            .is_export = ctx.is_export,
            .is_inline = ctx.is_always_inline,
            .is_var_args = switch (func_ty.kind) {
                .normal => false,
                .variadic => true,
                .old_style => !ctx.is_export and !ctx.is_always_inline,
            },
            .name = ctx.fn_name,
            .linksection_string = linksection_string,
            .explicit_callconv = explicit_callconv,
            .params = fn_params,
            .return_type = return_type_node,
            .body = null,
            .alignment = alignment,
        },
    };
    return ZigNode.initPayload(&payload.base);
}

/// Produces a Zig AST node by translating a Type, respecting the width, but modifying the signed-ness.
/// Asserts the type is an integer.
fn transTypeIntWidthOf(t: *Translator, qt: QualType, is_signed: bool) TypeError!ZigNode {
    return ZigTag.type.create(t.arena, switch (qt.base(t.comp).type) {
        .int => |int_ty| switch (int_ty) {
            .char, .schar, .uchar => if (is_signed) "i8" else "u8",
            .short, .ushort => if (is_signed) "c_short" else "c_ushort",
            .int, .uint => if (is_signed) "c_int" else "c_uint",
            .long, .ulong => if (is_signed) "c_long" else "c_ulong",
            .long_long, .ulong_long => if (is_signed) "c_longlong" else "c_ulonglong",
            .int128, .uint128 => if (is_signed) "i128" else "u128",
        },
        .bit_int => |bit_int_ty| try std.fmt.allocPrint(t.arena, "{s}{d}", .{
            if (is_signed) "i" else "u",
            bit_int_ty.bits,
        }),
        else => unreachable, // only call this function when it has already been determined the type is int
    });
}

// ============
// Type helpers
// ============

fn typeIsOpaque(t: *Translator, qt: QualType) bool {
    return switch (qt.base(t.comp).type) {
        .void => true,
        .@"struct", .@"union" => |record_ty| {
            if (record_ty.layout == null) return true;
            for (record_ty.fields) |field| {
                if (field.bit_width != .null) return true;
            }
            return false;
        },
        else => false,
    };
}

fn typeWasDemotedToOpaque(t: *Translator, qt: QualType) bool {
    const base = qt.base(t.comp);
    switch (base.type) {
        .@"struct", .@"union" => |record_ty| {
            if (t.opaque_demotes.contains(base.qt)) return true;
            for (record_ty.fields) |field| {
                if (t.typeWasDemotedToOpaque(field.qt)) return true;
            }
            return false;
        },
        .@"enum" => return t.opaque_demotes.contains(base.qt),
        else => return false,
    }
}

fn typeHasWrappingOverflow(t: *Translator, qt: QualType) bool {
    if (qt.isInt(t.comp) and qt.signedness(t.comp) == .unsigned) {
        // unsigned integer overflow wraps around.
        return true;
    } else {
        // float, signed integer, and pointer overflow is undefined behavior.
        return false;
    }
}

// =====================
// Statement translation
// =====================

fn transStmt(t: *Translator, scope: *Scope, stmt: Node.Index) TransError!ZigNode {
    switch (stmt.get(t.tree)) {
        .compound_stmt => |compound| {
            return t.transCompoundStmt(scope, compound);
        },
        .static_assert => |static_assert| {
            try t.transStaticAssert(scope, static_assert);
            return ZigTag.declaration.init();
        },
        .return_stmt => |return_stmt| return t.transReturnStmt(scope, return_stmt),
        .null_stmt => return ZigTag.empty_block.init(),
        .if_stmt => |if_stmt| return t.transIfStmt(scope, if_stmt),
        .while_stmt => |while_stmt| return t.transWhileStmt(scope, while_stmt),
        .do_while_stmt => |do_while_stmt| return t.transDoWhileStmt(scope, do_while_stmt),
        .for_stmt => |for_stmt| return t.transForStmt(scope, for_stmt),
        .continue_stmt => return ZigTag.@"continue".init(),
        .break_stmt => return ZigTag.@"break".init(),
        .typedef => |typedef_decl| {
            assert(!typedef_decl.implicit);
            try t.transTypeDef(scope, stmt);
            return ZigTag.declaration.init();
        },
        .struct_decl, .union_decl => |record_decl| {
            try t.transRecordDecl(scope, record_decl.container_qt);
            return ZigTag.declaration.init();
        },
        .enum_decl => |enum_decl| {
            try t.transEnumDecl(scope, enum_decl.container_qt);
            return ZigTag.declaration.init();
        },
        .fn_proto => {
            try t.transFnDecl(scope, stmt);
            return ZigTag.declaration.init();
        },
        .variable => |variable| {
            try t.transVarDecl(scope, variable);
            return ZigTag.declaration.init();
        },
        else => return t.transExprCoercing(scope, stmt, .unused),
    }
}

fn transCompoundStmtInline(t: *Translator, compound: Node.CompoundStmt, block: *Scope.Block) TransError!void {
    for (compound.body) |stmt| {
        const result = try t.transStmt(&block.base, stmt);
        switch (result.tag()) {
            .declaration, .empty_block => {},
            else => try block.statements.append(t.gpa, result),
        }
    }
}

fn transCompoundStmt(t: *Translator, scope: *Scope, compound: Node.CompoundStmt) TransError!ZigNode {
    var block_scope = try Scope.Block.init(t, scope, false);
    defer block_scope.deinit();
    try t.transCompoundStmtInline(compound, &block_scope);
    return try block_scope.complete();
}

fn transReturnStmt(t: *Translator, scope: *Scope, return_stmt: Node.ReturnStmt) TransError!ZigNode {
    switch (return_stmt.operand) {
        .none => return ZigTag.return_void.init(),
        .expr => |operand| {
            var rhs = try t.transExprCoercing(scope, operand, .used);
            const return_qt = scope.findBlockReturnType();
            if (rhs.isBoolRes() and !return_qt.is(t.comp, .bool)) {
                rhs = try ZigTag.int_from_bool.create(t.arena, rhs);
            }
            return ZigTag.@"return".create(t.arena, rhs);
        },
        .implicit => |zero| {
            if (zero) return ZigTag.@"return".create(t.arena, ZigTag.zero_literal.init());

            const return_qt = scope.findBlockReturnType();
            if (return_qt.is(t.comp, .void)) return ZigTag.empty_block.init();

            return ZigTag.@"return".create(t.arena, ZigTag.undefined_literal.init());
        },
    }
}

/// If a statement can possibly translate to a Zig assignment (either directly because it's
/// an assignment in C or indirectly via result assignment to `_`) AND it's the sole statement
/// in the body of an if statement or loop, then we need to put the statement into its own block.
/// The `else` case here corresponds to statements that could result in an assignment. If a statement
/// class never needs a block, add its enum to the top prong.
fn maybeBlockify(t: *Translator, scope: *Scope, stmt: Node.Index) TransError!ZigNode {
    switch (stmt.get(t.tree)) {
        .break_stmt,
        .continue_stmt,
        .compound_stmt,
        .decl_ref_expr,
        .enumeration_ref,
        .do_while_stmt,
        .for_stmt,
        .if_stmt,
        .return_stmt,
        .null_stmt,
        .while_stmt,
        => return t.transStmt(scope, stmt),
        else => return t.blockify(scope, stmt),
    }
}

/// Translate statement and place it in its own block.
fn blockify(t: *Translator, scope: *Scope, stmt: Node.Index) TransError!ZigNode {
    var block_scope = try Scope.Block.init(t, scope, false);
    defer block_scope.deinit();
    const result = try t.transStmt(&block_scope.base, stmt);
    try block_scope.statements.append(t.gpa, result);
    return block_scope.complete();
}

fn transIfStmt(t: *Translator, scope: *Scope, if_stmt: Node.IfStmt) TransError!ZigNode {
    var cond_scope: Scope.Condition = .{
        .base = .{
            .parent = scope,
            .id = .condition,
        },
    };
    defer cond_scope.deinit();
    const cond = try t.transBoolExpr(&cond_scope.base, if_stmt.cond);

    // block needed to keep else statement from attaching to inner while
    const must_blockify = (if_stmt.else_body != null) and switch (if_stmt.then_body.get(t.tree)) {
        .while_stmt, .do_while_stmt, .for_stmt => true,
        else => false,
    };

    const then_node = if (must_blockify)
        try t.blockify(scope, if_stmt.then_body)
    else
        try t.maybeBlockify(scope, if_stmt.then_body);

    const else_node = if (if_stmt.else_body) |stmt|
        try t.maybeBlockify(scope, stmt)
    else
        null;
    return ZigTag.@"if".create(t.arena, .{ .cond = cond, .then = then_node, .@"else" = else_node });
}

fn transWhileStmt(t: *Translator, scope: *Scope, while_stmt: Node.WhileStmt) TransError!ZigNode {
    var cond_scope: Scope.Condition = .{
        .base = .{
            .parent = scope,
            .id = .condition,
        },
    };
    defer cond_scope.deinit();
    const cond = try t.transBoolExpr(&cond_scope.base, while_stmt.cond);

    var loop_scope: Scope = .{
        .parent = scope,
        .id = .loop,
    };
    const body = try t.maybeBlockify(&loop_scope, while_stmt.body);
    return ZigTag.@"while".create(t.arena, .{ .cond = cond, .body = body, .cont_expr = null });
}

fn transDoWhileStmt(t: *Translator, scope: *Scope, do_stmt: Node.DoWhileStmt) TransError!ZigNode {
    var loop_scope: Scope = .{
        .parent = scope,
        .id = .do_loop,
    };

    // if (!cond) break;
    var cond_scope: Scope.Condition = .{
        .base = .{
            .parent = scope,
            .id = .condition,
        },
    };
    defer cond_scope.deinit();
    const cond = try t.transBoolExpr(&cond_scope.base, do_stmt.cond);
    const if_not_break = switch (cond.tag()) {
        .true_literal => {
            const body_node = try t.maybeBlockify(scope, do_stmt.body);
            return ZigTag.while_true.create(t.arena, body_node);
        },
        else => try ZigTag.if_not_break.create(t.arena, cond),
    };

    var body_node = try t.transStmt(&loop_scope, do_stmt.body);
    if (body_node.isNoreturn(true)) {
        // The body node ends in a noreturn statement. Simply put it in a while (true)
        // in case it contains breaks or continues.
    } else if (do_stmt.body.get(t.tree) == .compound_stmt) {
        // there's already a block in C, so we'll append our condition to it.
        // c: do {
        // c:   a;
        // c:   b;
        // c: } while(c);
        // zig: while (true) {
        // zig:   a;
        // zig:   b;
        // zig:   if (!cond) break;
        // zig: }
        const block = body_node.castTag(.block).?;
        block.data.stmts.len += 1; // This is safe since we reserve one extra space in Scope.Block.complete.
        block.data.stmts[block.data.stmts.len - 1] = if_not_break;
    } else {
        // the C statement is without a block, so we need to create a block to contain it.
        // c: do
        // c:   a;
        // c: while(c);
        // zig: while (true) {
        // zig:   a;
        // zig:   if (!cond) break;
        // zig: }
        const statements = try t.arena.alloc(ZigNode, 2);
        statements[0] = body_node;
        statements[1] = if_not_break;
        body_node = try ZigTag.block.create(t.arena, .{ .label = null, .stmts = statements });
    }
    return ZigTag.while_true.create(t.arena, body_node);
}

fn transForStmt(t: *Translator, scope: *Scope, for_stmt: Node.ForStmt) TransError!ZigNode {
    var loop_scope: Scope = .{
        .parent = scope,
        .id = .loop,
    };

    var block_scope: ?Scope.Block = null;
    defer if (block_scope) |*bs| bs.deinit();

    switch (for_stmt.init) {
        .decls => |decls| {
            block_scope = try Scope.Block.init(t, scope, false);
            loop_scope.parent = &block_scope.?.base;
            for (decls) |decl| {
                try t.transDecl(&block_scope.?.base, decl);
            }
        },
        .expr => |maybe_init| if (maybe_init) |init| {
            block_scope = try Scope.Block.init(t, scope, false);
            loop_scope.parent = &block_scope.?.base;
            const init_node = try t.transStmt(&block_scope.?.base, init);
            try loop_scope.appendNode(init_node);
        },
    }
    var cond_scope: Scope.Condition = .{
        .base = .{
            .parent = &loop_scope,
            .id = .condition,
        },
    };
    defer cond_scope.deinit();

    const cond = if (for_stmt.cond) |cond|
        try t.transBoolExpr(&cond_scope.base, cond)
    else
        ZigTag.true_literal.init();

    const cont_expr = if (for_stmt.incr) |incr|
        try t.transExpr(&cond_scope.base, incr, .unused)
    else
        null;

    const body = try t.maybeBlockify(&loop_scope, for_stmt.body);
    const while_node = try ZigTag.@"while".create(t.arena, .{ .cond = cond, .body = body, .cont_expr = cont_expr });
    if (block_scope) |*bs| {
        try bs.statements.append(t.gpa, while_node);
        return try bs.complete();
    } else {
        return while_node;
    }
}

// ======================
// Expression translation
// ======================

const ResultUsed = enum { used, unused };

fn transExpr(t: *Translator, scope: *Scope, expr: Node.Index, used: ResultUsed) TransError!ZigNode {
    const qt = expr.qt(t.tree);
    return t.maybeSuppressResult(used, switch (expr.get(t.tree)) {
        .paren_expr => |paren_expr| {
            return t.transExpr(scope, paren_expr.operand, used);
        },
        .cast => |cast| return t.transCastExpr(scope, cast, used, .with_as),
        .decl_ref_expr => |decl_ref| try t.transDeclRefExpr(scope, decl_ref),
        .enumeration_ref => |enum_ref| try t.transDeclRefExpr(scope, enum_ref),
        .addr_of_expr => |addr_of_expr| try ZigTag.address_of.create(t.arena, try t.transExpr(scope, addr_of_expr.operand, .used)),
        .deref_expr => |deref_expr| res: {
            if (t.typeWasDemotedToOpaque(qt))
                return t.fail(error.UnsupportedTranslation, deref_expr.op_tok, "cannot dereference opaque type", .{});

            // Dereferencing a function pointer is a no-op.
            if (qt.is(t.comp, .func)) return t.transExpr(scope, deref_expr.operand, used);

            break :res try ZigTag.deref.create(t.arena, try t.transExpr(scope, deref_expr.operand, .used));
        },
        .bool_not_expr => |bool_not_expr| try ZigTag.not.create(t.arena, try t.transBoolExpr(scope, bool_not_expr.operand)),
        .bit_not_expr => |bit_not_expr| try ZigTag.bit_not.create(t.arena, try t.transExpr(scope, bit_not_expr.operand, .used)),
        .plus_expr => |plus_expr| return t.transExpr(scope, plus_expr.operand, used),
        .negate_expr => |negate_expr| res: {
            const operand_qt = negate_expr.operand.qt(t.tree);
            if (!t.typeHasWrappingOverflow(operand_qt)) {
                const sub_expr_node = try t.transExpr(scope, negate_expr.operand, .used);
                const to_negate = if (sub_expr_node.isBoolRes()) blk: {
                    const ty_node = try ZigTag.type.create(t.arena, "c_int");
                    const int_node = try ZigTag.int_from_bool.create(t.arena, sub_expr_node);
                    break :blk try ZigTag.as.create(t.arena, .{ .lhs = ty_node, .rhs = int_node });
                } else sub_expr_node;

                break :res try ZigTag.negate.create(t.arena, to_negate);
            } else if (qt.isInt(t.comp) and operand_qt.signedness(t.comp) == .unsigned) {
                // use -% x for unsigned integers
                break :res try ZigTag.negate_wrap.create(t.arena, try t.transExpr(scope, negate_expr.operand, .used));
            } else return t.fail(error.UnsupportedTranslation, negate_expr.op_tok, "C negation with non float non integer", .{});
        },
        .div_expr => |div_expr| res: {
            if (qt.isInt(t.comp) and qt.signedness(t.comp) == .signed) {
                // signed integer division uses @divTrunc
                const lhs = try t.transExpr(scope, div_expr.lhs, .used);
                const rhs = try t.transExpr(scope, div_expr.rhs, .used);
                break :res try ZigTag.div_trunc.create(t.arena, .{ .lhs = lhs, .rhs = rhs });
            }
            // unsigned/float division uses the operator
            break :res try t.transBinExpr(scope, div_expr, .div);
        },
        .mod_expr => |mod_expr| res: {
            if (qt.isInt(t.comp) and qt.signedness(t.comp) == .signed) {
                // signed integer remainder uses __helpers.signedRemainder
                const lhs = try t.transExpr(scope, mod_expr.lhs, .used);
                const rhs = try t.transExpr(scope, mod_expr.rhs, .used);
                break :res try t.createHelperCallNode(.signedRemainder, &.{ lhs, rhs });
            }
            // unsigned/float division uses the operator
            break :res try t.transBinExpr(scope, mod_expr, .mod);
        },
        .add_expr => |add_expr| res: {
            // `ptr + idx` and `idx + ptr` -> ptr + @as(usize, @bitCast(@as(isize, @intCast(idx))))
            if (qt.isPointer(t.comp) and (add_expr.lhs.qt(t.tree).signedness(t.comp) == .signed or
                add_expr.rhs.qt(t.tree).signedness(t.comp) == .signed))
            {
                break :res try t.transPointerArithmeticSignedOp(scope, add_expr, .add);
            }

            if (qt.isInt(t.comp) and qt.signedness(t.comp) == .unsigned) {
                break :res try t.transBinExpr(scope, add_expr, .add_wrap);
            } else {
                break :res try t.transBinExpr(scope, add_expr, .add);
            }
        },
        .sub_expr => |sub_expr| res: {
            // `ptr - idx` -> ptr - @as(usize, @bitCast(@as(isize, @intCast(idx))))
            if (qt.isPointer(t.comp) and (sub_expr.lhs.qt(t.tree).signedness(t.comp) == .signed or
                sub_expr.rhs.qt(t.tree).signedness(t.comp) == .signed))
            {
                break :res try t.transPointerArithmeticSignedOp(scope, sub_expr, .sub);
            }

            if (sub_expr.lhs.qt(t.tree).isPointer(t.comp) and sub_expr.rhs.qt(t.tree).isPointer(t.comp)) {
                break :res try t.transPtrDiffExpr(scope, sub_expr);
            } else if (qt.isInt(t.comp) and qt.signedness(t.comp) == .unsigned) {
                break :res try t.transBinExpr(scope, sub_expr, .sub_wrap);
            } else {
                break :res try t.transBinExpr(scope, sub_expr, .sub);
            }
        },
        .mul_expr => |mul_expr| if (qt.isInt(t.comp) and qt.signedness(t.comp) == .unsigned)
            try t.transBinExpr(scope, mul_expr, .mul_wrap)
        else
            try t.transBinExpr(scope, mul_expr, .mul),

        .less_than_expr => |lt| try t.transBinExpr(scope, lt, .less_than),
        .greater_than_expr => |gt| try t.transBinExpr(scope, gt, .greater_than),
        .less_than_equal_expr => |lte| try t.transBinExpr(scope, lte, .less_than_equal),
        .greater_than_equal_expr => |gte| try t.transBinExpr(scope, gte, .greater_than_equal),
        .equal_expr => |equal_expr| try t.transBinExpr(scope, equal_expr, .equal),
        .not_equal_expr => |not_equal_expr| try t.transBinExpr(scope, not_equal_expr, .not_equal),

        .bool_and_expr => |bool_and_expr| try t.transBoolBinExpr(scope, bool_and_expr, .@"and"),
        .bool_or_expr => |bool_or_expr| try t.transBoolBinExpr(scope, bool_or_expr, .@"or"),

        .bit_and_expr => |bit_and_expr| try t.transBinExpr(scope, bit_and_expr, .bit_and),
        .bit_or_expr => |bit_or_expr| try t.transBinExpr(scope, bit_or_expr, .bit_or),
        .bit_xor_expr => |bit_xor_expr| try t.transBinExpr(scope, bit_xor_expr, .bit_xor),

        .shl_expr => |shl_expr| try t.transShiftExpr(scope, shl_expr, .shl),
        .shr_expr => |shr_expr| try t.transShiftExpr(scope, shr_expr, .shr),

        .member_access_expr => |member_access| try t.transMemberAccess(scope, .normal, member_access),
        .member_access_ptr_expr => |member_access| try t.transMemberAccess(scope, .ptr, member_access),
        .array_access_expr => |array_access| try t.transArrayAccess(scope, array_access),

        .builtin_ref => unreachable,
        .builtin_call_expr => |call| return t.transBuiltinCall(scope, call, used),
        .call_expr => |call| return t.transCall(scope, call, used),

        .builtin_types_compatible_p => |compatible| blk: {
            const lhs = try t.transType(scope, compatible.lhs, compatible.builtin_tok);
            const rhs = try t.transType(scope, compatible.rhs, compatible.builtin_tok);

            break :blk try ZigTag.equal.create(t.arena, .{
                .lhs = lhs,
                .rhs = rhs,
            });
        },
        .builtin_choose_expr => |choose| return t.transCondExpr(scope, choose, used),
        .cond_expr => |cond_expr| return t.transCondExpr(scope, cond_expr, used),
        .binary_cond_expr => |conditional| return t.transBinaryCondExpr(scope, conditional, used),
        .cond_dummy_expr => unreachable,

        .assign_expr => |assign| return t.transAssignExpr(scope, assign, used),
        .add_assign_expr => |assign| return t.transCompoundAssign(scope, assign, if (t.typeHasWrappingOverflow(assign.qt))
            .add_wrap_assign
        else
            .add_assign, used),
        .sub_assign_expr => |assign| return t.transCompoundAssign(scope, assign, if (t.typeHasWrappingOverflow(assign.qt))
            .sub_wrap_assign
        else
            .sub_assign, used),
        .mul_assign_expr => |assign| return t.transCompoundAssign(scope, assign, if (t.typeHasWrappingOverflow(assign.qt))
            .mul_wrap_assign
        else
            .mul_assign, used),
        .div_assign_expr => |assign| return t.transCompoundAssign(scope, assign, .div_assign, used),
        .mod_assign_expr => |assign| return t.transCompoundAssign(scope, assign, .mod_assign, used),
        .shl_assign_expr => |assign| return t.transCompoundAssign(scope, assign, .shl_assign, used),
        .shr_assign_expr => |assign| return t.transCompoundAssign(scope, assign, .shr_assign, used),
        .bit_and_assign_expr => |assign| return t.transCompoundAssign(scope, assign, .bit_and_assign, used),
        .bit_xor_assign_expr => |assign| return t.transCompoundAssign(scope, assign, .bit_xor_assign, used),
        .bit_or_assign_expr => |assign| return t.transCompoundAssign(scope, assign, .bit_or_assign, used),

        .comma_expr => |comma_expr| return t.transCommaExpr(scope, comma_expr, used),
        .pre_inc_expr => |un| return t.transIncDecExpr(scope, un, .pre, .inc, used),
        .pre_dec_expr => |un| return t.transIncDecExpr(scope, un, .pre, .dec, used),
        .post_inc_expr => |un| return t.transIncDecExpr(scope, un, .post, .inc, used),
        .post_dec_expr => |un| return t.transIncDecExpr(scope, un, .post, .dec, used),

        .int_literal => return t.transIntLiteral(scope, expr, used, .with_as),
        .char_literal => return t.transCharLiteral(scope, expr, used, .with_as),
        .float_literal => return t.transFloatLiteral(scope, expr, used, .with_as),
        .string_literal_expr => |literal| res: {
            const val = t.tree.value_map.get(expr).?;
            const str_qt = literal.qt;

            const bytes = t.comp.interner.get(val.ref()).bytes;
            var buf = std.ArrayList(u8).init(t.gpa);
            defer buf.deinit();

            try buf.ensureUnusedCapacity(bytes.len);
            try aro.Value.printString(bytes, str_qt, t.comp, buf.writer());

            break :res try ZigTag.string_literal.create(t.arena, try t.arena.dupe(u8, buf.items));
        },
        .bool_literal => res: {
            const val = t.tree.value_map.get(expr).?;
            break :res if (val.toBool(t.comp))
                ZigTag.true_literal.init()
            else
                ZigTag.false_literal.init();
        },
        .nullptr_literal => ZigTag.null_literal.init(),
        .imaginary_literal => |literal| {
            return t.fail(error.UnsupportedTranslation, literal.op_tok, "TODO complex numbers", .{});
        },
        .compound_literal_expr => |literal| return t.transCompoundLiteral(scope, literal, used),

        .default_init_expr => |default_init| return t.transDefaultInit(scope, default_init, used, .with_as),
        .array_init_expr => |array_init| return t.transArrayInit(scope, array_init, used),
        .union_init_expr => |union_init| return t.transUnionInit(scope, union_init, used),
        .struct_init_expr => |struct_init| return t.transStructInit(scope, struct_init, used),
        .array_filler_expr => unreachable,

        .sizeof_expr => |sizeof| try t.transTypeInfo(scope, .sizeof, sizeof),
        .alignof_expr => |alignof| try t.transTypeInfo(scope, .alignof, alignof),

        .imag_expr, .real_expr => |un| {
            return t.fail(error.UnsupportedTranslation, un.op_tok, "TODO complex numbers", .{});
        },
        .addr_of_label => |addr_of_label| {
            return t.fail(error.UnsupportedTranslation, addr_of_label.label_tok, "TODO computed goto", .{});
        },

        .generic_expr => |generic| return t.transExpr(scope, generic.chosen, used),
        .generic_association_expr => unreachable,
        .generic_default_expr => unreachable,

        .stmt_expr => |stmt_expr| return t.transStmtExpr(scope, stmt_expr, used),

        .compound_stmt,
        .static_assert,
        .return_stmt,
        .null_stmt,
        .if_stmt,
        .while_stmt,
        .do_while_stmt,
        .for_stmt,
        .continue_stmt,
        .break_stmt,
        .labeled_stmt,
        .switch_stmt,
        .case_stmt,
        .default_stmt,
        .goto_stmt,
        .computed_goto_stmt,
        .gnu_asm_simple,
        .global_asm,
        .typedef,
        .struct_decl,
        .union_decl,
        .enum_decl,
        .fn_proto,
        .fn_def,
        .param,
        .variable,
        .enum_field,
        .record_field,
        .struct_forward_decl,
        .union_forward_decl,
        .enum_forward_decl,
        .empty_decl,
        => unreachable, // not an expression
    });
}

/// Same as `transExpr` but with the knowledge that the operand will be type coerced, and therefore
/// an `@as` would be redundant. This is used to prevent redundant `@as` in integer literals.
fn transExprCoercing(t: *Translator, scope: *Scope, expr: Node.Index, used: ResultUsed) TransError!ZigNode {
    switch (expr.get(t.tree)) {
        .int_literal => return t.transIntLiteral(scope, expr, used, .no_as),
        .char_literal => return t.transCharLiteral(scope, expr, used, .no_as),
        .float_literal => return t.transFloatLiteral(scope, expr, used, .no_as),
        .cast => |cast| switch (cast.kind) {
            .lval_to_rval, .no_op => return t.transExprCoercing(scope, cast.operand, used),
            else => return t.transCastExpr(scope, cast, used, .no_as),
        },
        .default_init_expr => |default_init| return try t.transDefaultInit(scope, default_init, used, .no_as),
        .compound_literal_expr => |literal| {
            if (!literal.thread_local and literal.storage_class != .static) {
                return t.transExprCoercing(scope, literal.initializer, used);
            }
        },
        else => {},
    }

    return t.transExpr(scope, expr, used);
}

fn transBoolExpr(t: *Translator, scope: *Scope, expr: Node.Index) TransError!ZigNode {
    switch (expr.get(t.tree)) {
        .int_literal => {
            const int_val = t.tree.value_map.get(expr).?;
            return if (int_val.isZero(t.comp))
                ZigTag.false_literal.init()
            else
                ZigTag.true_literal.init();
        },
        .cast => |cast| {
            if (cast.kind == .bool_to_int) {
                return t.transExpr(scope, cast.operand, .used);
            }
        },
        else => {},
    }

    const maybe_bool_res = try t.transExpr(scope, expr, .used);
    if (maybe_bool_res.isBoolRes()) {
        return maybe_bool_res;
    }

    return t.finishBoolExpr(expr.qt(t.tree), maybe_bool_res);
}

fn finishBoolExpr(t: *Translator, qt: QualType, node: ZigNode) TransError!ZigNode {
    const sk = qt.scalarKind(t.comp);
    if (sk == .nullptr_t) {
        // node == null, always true
        return ZigTag.equal.create(t.arena, .{ .lhs = node, .rhs = ZigTag.null_literal.init() });
    }
    if (sk.isPointer()) {
        if (node.tag() == .string_literal) {
            // @intFromPtr(node) != 0, always true
            const int_from_ptr = try ZigTag.int_from_ptr.create(t.arena, node);
            return ZigTag.not_equal.create(t.arena, .{ .lhs = int_from_ptr, .rhs = ZigTag.zero_literal.init() });
        }
        // node != null
        return ZigTag.not_equal.create(t.arena, .{ .lhs = node, .rhs = ZigTag.null_literal.init() });
    }
    if (sk != .none) {
        // node != 0
        return ZigTag.not_equal.create(t.arena, .{ .lhs = node, .rhs = ZigTag.zero_literal.init() });
    }
    unreachable; // Unexpected bool expression type
}

fn transCastExpr(
    t: *Translator,
    scope: *Scope,
    cast: Node.Cast,
    used: ResultUsed,
    suppress_as: SuppressCast,
) TransError!ZigNode {
    const to_cast = to_cast: {
        switch (cast.kind) {
            .lval_to_rval, .no_op, .function_to_pointer => {
                return t.transExpr(scope, cast.operand, used);
            },
            .int_cast => {
                const dest_qt = cast.qt;
                const src_qt = cast.operand.qt(t.tree);

                if (cast.implicit) {
                    if (t.tree.value_map.get(cast.operand)) |val| {
                        const max_int = try aro.Value.maxInt(cast.qt, t.comp);

                        if (val.compare(.lte, max_int, t.comp)) {
                            break :to_cast try t.transExprCoercing(scope, cast.operand, .used);
                        }
                    }
                }

                const src_dest_order = src_qt.intRankOrder(dest_qt, t.comp);
                const needs_bitcast = src_qt.signedness(t.comp) != dest_qt.signedness(t.comp);

                var operand = try t.transExprCoercing(scope, cast.operand, .used);
                if (src_dest_order == .gt) {
                    operand = try ZigTag.truncate.create(t.arena, operand);
                }
                if (needs_bitcast and src_dest_order != .eq) {
                    operand = try ZigTag.as.create(t.arena, .{
                        .lhs = try t.transTypeIntWidthOf(dest_qt, src_qt.signedness(t.comp) == .signed),
                        .rhs = operand,
                    });
                }
                if (needs_bitcast) {
                    break :to_cast try ZigTag.bit_cast.create(t.arena, operand);
                }
                break :to_cast operand;
            },
            .to_void => {
                assert(used == .unused);
                return try t.transExpr(scope, cast.operand, .unused);
            },
            .null_to_pointer => {
                break :to_cast ZigTag.null_literal.init();
            },
            .array_to_pointer => {
                if (t.tree.value_map.get(cast.operand)) |val| {
                    const str_qt = cast.qt;
                    const bytes = t.comp.interner.get(val.ref()).bytes;
                    var buf = std.ArrayList(u8).init(t.gpa);
                    defer buf.deinit();

                    try buf.ensureUnusedCapacity(bytes.len);
                    try aro.Value.printString(bytes, str_qt, t.comp, buf.writer());

                    const string_node = try ZigTag.string_literal.create(t.arena, try t.arena.dupe(u8, buf.items));
                    return t.maybeSuppressResult(used, string_node);
                }

                if (cast.operand.qt(t.tree).arrayLen(t.comp) == null) {
                    return try t.transExpr(scope, cast.operand, used);
                }

                const sub_expr_node = try t.transExpr(scope, cast.operand, .used);
                const ref = try ZigTag.address_of.create(t.arena, sub_expr_node);
                const align_cast = try ZigTag.align_cast.create(t.arena, ref);
                break :to_cast try ZigTag.ptr_cast.create(t.arena, align_cast);
            },
            .int_to_pointer => {
                const sub_expr_node = try t.transExpr(scope, cast.operand, .used);
                break :to_cast try ZigTag.ptr_from_int.create(t.arena, sub_expr_node);
            },
            .int_to_bool => {
                const sub_expr_node = try t.transExpr(scope, cast.operand, .used);
                if (sub_expr_node.isBoolRes()) return sub_expr_node;
                const cmp_node = try ZigTag.not_equal.create(t.arena, .{ .lhs = sub_expr_node, .rhs = ZigTag.zero_literal.init() });
                return t.maybeSuppressResult(used, cmp_node);
            },
            .float_to_bool => {
                const sub_expr_node = try t.transExpr(scope, cast.operand, .used);
                const cmp_node = try ZigTag.not_equal.create(t.arena, .{ .lhs = sub_expr_node, .rhs = ZigTag.zero_literal.init() });
                return t.maybeSuppressResult(used, cmp_node);
            },
            .pointer_to_bool => {
                const sub_expr_node = try t.transExpr(scope, cast.operand, .used);

                // Special case function pointers as @intFromPtr(expr) != 0
                if (cast.operand.qt(t.tree).get(t.comp, .pointer)) |ptr_ty| if (ptr_ty.child.is(t.comp, .func)) {
                    const int_from_ptr = try ZigTag.int_from_ptr.create(t.arena, sub_expr_node);
                    const cmp_node = try ZigTag.not_equal.create(t.arena, .{ .lhs = int_from_ptr, .rhs = ZigTag.zero_literal.init() });
                    return t.maybeSuppressResult(used, cmp_node);
                };

                const cmp_node = try ZigTag.not_equal.create(t.arena, .{ .lhs = sub_expr_node, .rhs = ZigTag.null_literal.init() });
                return t.maybeSuppressResult(used, cmp_node);
            },
            .bool_to_int => {
                const sub_expr_node = try t.transExprCoercing(scope, cast.operand, .used);
                break :to_cast try ZigTag.int_from_bool.create(t.arena, sub_expr_node);
            },
            .bool_to_float => {
                const sub_expr_node = try t.transExprCoercing(scope, cast.operand, .used);
                const int_from_bool = try ZigTag.int_from_bool.create(t.arena, sub_expr_node);
                break :to_cast try ZigTag.float_from_int.create(t.arena, int_from_bool);
            },
            .bool_to_pointer => {
                const sub_expr_node = try t.transExprCoercing(scope, cast.operand, .used);
                const int_from_bool = try ZigTag.int_from_bool.create(t.arena, sub_expr_node);
                break :to_cast try ZigTag.ptr_from_int.create(t.arena, int_from_bool);
            },
            .float_cast => {
                const sub_expr_node = try t.transExprCoercing(scope, cast.operand, .used);
                break :to_cast try ZigTag.float_cast.create(t.arena, sub_expr_node);
            },
            .int_to_float => return t.transExprCoercing(scope, cast.operand, used),
            .float_to_int => {
                const sub_expr_node = try t.transExprCoercing(scope, cast.operand, .used);
                break :to_cast try ZigTag.int_from_float.create(t.arena, sub_expr_node);
            },
            .pointer_to_int => {
                const sub_expr_node = try t.transExpr(scope, cast.operand, .used);
                break :to_cast try ZigTag.int_from_ptr.create(t.arena, sub_expr_node);
            },
            .bitcast => {
                const sub_expr_node = try t.transExpr(scope, cast.operand, .used);
                if (cast.qt.isPointer(t.comp) and cast.operand.qt(t.tree).isPointer(t.comp)) {
                    const align_cast = try ZigTag.align_cast.create(t.arena, sub_expr_node);
                    break :to_cast try ZigTag.ptr_cast.create(t.arena, align_cast);
                }
            },
            else => {},
        }
        return t.fail(error.UnsupportedTranslation, cast.l_paren, "TODO translate {s} cast", .{@tagName(cast.kind)});
    };
    if (suppress_as == .no_as) return t.maybeSuppressResult(used, to_cast);
    if (used == .unused) return t.maybeSuppressResult(used, to_cast);
    const as = try ZigTag.as.create(t.arena, .{
        .lhs = try t.transType(scope, cast.qt, cast.l_paren),
        .rhs = to_cast,
    });
    return as;
}

fn transDeclRefExpr(t: *Translator, scope: *Scope, decl_ref: Node.DeclRef) TransError!ZigNode {
    const name = t.tree.tokSlice(decl_ref.name_tok);
    const maybe_alias = scope.getAlias(name);
    const mangled_name = maybe_alias orelse name;

    const decl = decl_ref.decl.get(t.tree);
    const ref_expr = blk: {
        const identifier = try ZigTag.identifier.create(t.arena, mangled_name);
        if (decl_ref.qt.is(t.comp, .func) and maybe_alias != null) {
            break :blk try ZigTag.field_access.create(t.arena, .{
                .lhs = identifier,
                .field_name = name,
            });
        }
        if (decl == .variable and maybe_alias != null) {
            switch (decl.variable.storage_class) {
                .@"extern", .static => {
                    break :blk try ZigTag.field_access.create(t.arena, .{
                        .lhs = identifier,
                        .field_name = name,
                    });
                },
                else => {},
            }
        }
        break :blk identifier;
    };

    scope.skipVariableDiscard(mangled_name);
    return ref_expr;
}

fn transBinExpr(t: *Translator, scope: *Scope, bin: Node.Binary, op_id: ZigTag) TransError!ZigNode {
    const lhs_uncasted = try t.transExpr(scope, bin.lhs, .used);
    const rhs_uncasted = try t.transExpr(scope, bin.rhs, .used);

    const lhs = if (lhs_uncasted.isBoolRes())
        try ZigTag.int_from_bool.create(t.arena, lhs_uncasted)
    else
        lhs_uncasted;

    const rhs = if (rhs_uncasted.isBoolRes())
        try ZigTag.int_from_bool.create(t.arena, rhs_uncasted)
    else
        rhs_uncasted;

    return t.createBinOpNode(op_id, lhs, rhs);
}

fn transBoolBinExpr(t: *Translator, scope: *Scope, bin: Node.Binary, op: ZigTag) !ZigNode {
    std.debug.assert(op == .@"and" or op == .@"or");

    const lhs = try t.transBoolExpr(scope, bin.lhs);
    const rhs = try t.transBoolExpr(scope, bin.rhs);

    return t.createBinOpNode(op, lhs, rhs);
}

fn transShiftExpr(t: *Translator, scope: *Scope, bin: Node.Binary, op_id: ZigTag) !ZigNode {
    std.debug.assert(op_id == .shl or op_id == .shr);

    // lhs >> @intCast(rh)
    const lhs = try t.transExpr(scope, bin.lhs, .used);

    const rhs = try t.transExprCoercing(scope, bin.rhs, .used);
    const rhs_casted = try ZigTag.int_cast.create(t.arena, rhs);

    return t.createBinOpNode(op_id, lhs, rhs_casted);
}

fn transCondExpr(
    t: *Translator,
    scope: *Scope,
    conditional: Node.Conditional,
    used: ResultUsed,
) TransError!ZigNode {
    var cond_scope: Scope.Condition = .{
        .base = .{
            .parent = scope,
            .id = .condition,
        },
    };
    defer cond_scope.deinit();

    const res_is_bool = conditional.qt.is(t.comp, .bool);
    const cond = try t.transBoolExpr(&cond_scope.base, conditional.cond);

    var then_body = try t.transExprCoercing(scope, conditional.then_expr, used);
    if (!res_is_bool and then_body.isBoolRes()) {
        then_body = try ZigTag.int_from_bool.create(t.arena, then_body);
    }

    var else_body = try t.transExprCoercing(scope, conditional.else_expr, used);
    if (!res_is_bool and else_body.isBoolRes()) {
        else_body = try ZigTag.int_from_bool.create(t.arena, else_body);
    }

    // The `ResultUsed` is forwarded to both branches so no need to suppress the result here.
    return ZigTag.@"if".create(t.arena, .{ .cond = cond, .then = then_body, .@"else" = else_body });
}

fn transBinaryCondExpr(
    t: *Translator,
    scope: *Scope,
    conditional: Node.Conditional,
    used: ResultUsed,
) TransError!ZigNode {
    // GNU extension of the ternary operator where the middle expression is
    // omitted, the condition itself is returned if it evaluates to true.

    if (used == .unused) {
        // Result unused so this can be translated as
        // if (condition) else_expr;
        var cond_scope: Scope.Condition = .{
            .base = .{
                .parent = scope,
                .id = .condition,
            },
        };
        defer cond_scope.deinit();

        return ZigTag.@"if".create(t.arena, .{
            .cond = try t.transBoolExpr(&cond_scope.base, conditional.cond),
            .then = try t.transExpr(scope, conditional.else_expr, .unused),
            .@"else" = null,
        });
    }

    const res_is_bool = conditional.qt.is(t.comp, .bool);
    // c:   (condition)?:(else_expr)
    // zig: (blk: {
    //          const _cond_temp = (condition);
    //          break :blk if (_cond_temp) _cond_temp else (else_expr);
    //      })
    var block_scope = try Scope.Block.init(t, scope, true);
    defer block_scope.deinit();

    const cond_temp = try block_scope.reserveMangledName("cond_temp");
    const init_node = try t.transExpr(&block_scope.base, conditional.cond, .used);
    const temp_decl = try ZigTag.var_simple.create(t.arena, .{ .name = cond_temp, .init = init_node });
    try block_scope.statements.append(t.gpa, temp_decl);

    var cond_scope: Scope.Condition = .{
        .base = .{
            .parent = &block_scope.base,
            .id = .condition,
        },
    };
    defer cond_scope.deinit();

    const cond_ident = try ZigTag.identifier.create(t.arena, cond_temp);
    const cond_node = try t.finishBoolExpr(conditional.cond.qt(t.tree), cond_ident);
    var then_body = cond_ident;
    if (!res_is_bool and init_node.isBoolRes()) {
        then_body = try ZigTag.int_from_bool.create(t.arena, then_body);
    }

    var else_body = try t.transExpr(&block_scope.base, conditional.else_expr, .used);
    if (!res_is_bool and else_body.isBoolRes()) {
        else_body = try ZigTag.int_from_bool.create(t.arena, else_body);
    }
    const if_node = try ZigTag.@"if".create(t.arena, .{
        .cond = cond_node,
        .then = then_body,
        .@"else" = else_body,
    });
    const break_node = try ZigTag.break_val.create(t.arena, .{
        .label = block_scope.label,
        .val = if_node,
    });
    try block_scope.statements.append(t.gpa, break_node);
    return block_scope.complete();
}

fn transCommaExpr(t: *Translator, scope: *Scope, bin: Node.Binary, used: ResultUsed) TransError!ZigNode {
    if (used == .unused) {
        const lhs = try t.transExprCoercing(scope, bin.lhs, .unused);
        try scope.appendNode(lhs);
        const rhs = try t.transExprCoercing(scope, bin.rhs, .unused);
        return rhs;
    }

    var block_scope = try Scope.Block.init(t, scope, true);
    defer block_scope.deinit();

    const lhs = try t.transExprCoercing(&block_scope.base, bin.lhs, .unused);
    try block_scope.statements.append(t.gpa, lhs);

    const rhs = try t.transExprCoercing(&block_scope.base, bin.rhs, .used);
    const break_node = try ZigTag.break_val.create(t.arena, .{
        .label = block_scope.label,
        .val = rhs,
    });
    try block_scope.statements.append(t.gpa, break_node);

    return try block_scope.complete();
}

fn transAssignExpr(t: *Translator, scope: *Scope, bin: Node.Binary, used: ResultUsed) !ZigNode {
    if (used == .unused) {
        const lhs = try t.transExpr(scope, bin.lhs, .used);
        var rhs = try t.transExprCoercing(scope, bin.rhs, .used);

        const lhs_qt = bin.lhs.qt(t.tree);
        if (rhs.isBoolRes() and !lhs_qt.is(t.comp, .bool)) {
            rhs = try ZigTag.int_from_bool.create(t.arena, rhs);
        }

        return t.createBinOpNode(.assign, lhs, rhs);
    }

    var block_scope = try Scope.Block.init(t, scope, true);
    defer block_scope.deinit();

    const tmp = try block_scope.reserveMangledName("tmp");

    var rhs = try t.transExprCoercing(&block_scope.base, bin.rhs, .used);
    const lhs_qt = bin.lhs.qt(t.tree);
    if (rhs.isBoolRes() and !lhs_qt.is(t.comp, .bool)) {
        rhs = try ZigTag.int_from_bool.create(t.arena, rhs);
    }

    const tmp_decl = try ZigTag.var_simple.create(t.arena, .{ .name = tmp, .init = rhs });
    try block_scope.statements.append(t.gpa, tmp_decl);

    const lhs = try t.transExprCoercing(&block_scope.base, bin.lhs, .used);
    const tmp_ident = try ZigTag.identifier.create(t.arena, tmp);

    const assign = try t.createBinOpNode(.assign, lhs, tmp_ident);
    try block_scope.statements.append(t.gpa, assign);

    const break_node = try ZigTag.break_val.create(t.arena, .{
        .label = block_scope.label,
        .val = tmp_ident,
    });
    try block_scope.statements.append(t.gpa, break_node);

    return try block_scope.complete();
}

fn transCompoundAssign(
    t: *Translator,
    scope: *Scope,
    assign: Node.Binary,
    op: ZigTag,
    used: ResultUsed,
) !ZigNode {
    const is_shift = op == .shl_assign or op == .shr_assign;
    const is_div = op == .div_assign;
    const is_mod = op == .mod_assign;
    const lhs_qt = assign.lhs.qt(t.tree);
    const rhs_qt = assign.rhs.qt(t.tree);
    const is_signed = lhs_qt.isInt(t.comp) and lhs_qt.signedness(t.comp) == .signed;
    // const is_ptr_arithmetic = lhs_qt.isPointer(t.comp) and rhs_qt.isInt(t.comp);
    const is_ptr_op_signed = lhs_qt.isPointer(t.comp) and rhs_qt.isInt(t.comp) and rhs_qt.signedness(t.comp) == .signed;
    // const requires_cast = !lhs_qt.eql(rhs_qt, t.comp) and !is_ptr_arithmetic;

    if (used == .unused) {
        // common case
        // c: lhs += rhs
        // zig: lhs += rhs
        const lhs_node = try t.transExpr(scope, assign.lhs, .used);
        var rhs_node = try t.transExprCoercing(scope, assign.rhs, .used);
        if (is_ptr_op_signed) rhs_node = try t.usizeCastForWrappingPtrArithmetic(rhs_node);

        if ((is_mod or is_div) and is_signed) {
            // if (requires_cast) rhs_node = try t.transCCast(scope, lhs_qt, rhs_qt, rhs_node);
            const builtin = if (is_mod)
                try t.createHelperCallNode(.signedRemainder, &.{ lhs_node, rhs_node })
            else
                try ZigTag.div_trunc.create(t.arena, .{ .lhs = lhs_node, .rhs = rhs_node });

            return t.createBinOpNode(.assign, lhs_node, builtin);
        }

        if (is_shift) {
            rhs_node = try ZigTag.int_cast.create(t.arena, rhs_node);
            // } else if (requires_cast) {
            //     rhs_node = try t.transCCast(scope, lhs_qt, rhs_qt, rhs_node);
        }
        return t.createBinOpNode(op, lhs_node, rhs_node);
    }
    // worst case
    // c:   lhs += rhs
    // zig: (blk: {
    // zig:     const _ref = &lhs;
    // zig:     _ref.* += rhs;
    // zig:     break :blk _ref.*
    // zig: })
    var block_scope = try Scope.Block.init(t, scope, true);
    defer block_scope.deinit();
    const ref = try block_scope.reserveMangledName("ref");

    const expr = try t.transExpr(&block_scope.base, assign.lhs, .used);
    const addr_of = try ZigTag.address_of.create(t.arena, expr);
    const ref_decl = try ZigTag.var_simple.create(t.arena, .{ .name = ref, .init = addr_of });
    try block_scope.statements.append(t.gpa, ref_decl);

    const lhs_node = try ZigTag.identifier.create(t.arena, ref);
    const ref_node = try ZigTag.deref.create(t.arena, lhs_node);

    var rhs_node = try t.transExprCoercing(&block_scope.base, assign.rhs, .used);
    if (is_ptr_op_signed) rhs_node = try t.usizeCastForWrappingPtrArithmetic(rhs_node);
    if ((is_mod or is_div) and is_signed) {
        // if (requires_cast) rhs_node = try t.transCCast(scope, lhs_qt, rhs_qt, rhs_node);
        const builtin = if (is_mod)
            try t.createHelperCallNode(.signedRemainder, &.{ ref_node, rhs_node })
        else
            try ZigTag.div_trunc.create(t.arena, .{ .lhs = ref_node, .rhs = rhs_node });

        const assign_node = try t.createBinOpNode(.assign, ref_node, builtin);
        try block_scope.statements.append(t.gpa, assign_node);
    } else {
        if (is_shift) {
            rhs_node = try ZigTag.int_cast.create(t.arena, rhs_node);
            // } else if (requires_cast) {
            //     rhs_node = try t.transCCast(&block_scope.base, lhs_qt, rhs_qt, rhs_node);
        }

        const assign_node = try t.createBinOpNode(op, ref_node, rhs_node);
        try block_scope.statements.append(t.gpa, assign_node);
    }

    const break_node = try ZigTag.break_val.create(t.arena, .{
        .label = block_scope.label,
        .val = ref_node,
    });
    try block_scope.statements.append(t.gpa, break_node);
    return block_scope.complete();
}

fn transIncDecExpr(
    t: *Translator,
    scope: *Scope,
    un: Node.Unary,
    position: enum { pre, post },
    kind: enum { inc, dec },
    used: ResultUsed,
) !ZigNode {
    const is_wrapping = t.typeHasWrappingOverflow(un.qt);
    const op: ZigTag = switch (kind) {
        .inc => if (is_wrapping) .add_wrap_assign else .add_assign,
        .dec => if (is_wrapping) .sub_wrap_assign else .sub_assign,
    };

    const one_literal = ZigTag.one_literal.init();
    if (used == .unused) {
        const operand = try t.transExpr(scope, un.operand, .used);
        return try t.createBinOpNode(op, operand, one_literal);
    }

    var block_scope = try Scope.Block.init(t, scope, true);
    defer block_scope.deinit();

    const ref = try block_scope.reserveMangledName("ref");
    const operand = try t.transExprCoercing(&block_scope.base, un.operand, .used);
    const operand_ref = try ZigTag.address_of.create(t.arena, operand);
    const ref_decl = try ZigTag.var_simple.create(t.arena, .{ .name = ref, .init = operand_ref });
    try block_scope.statements.append(t.gpa, ref_decl);

    const ref_ident = try ZigTag.identifier.create(t.arena, ref);
    const ref_deref = try ZigTag.deref.create(t.arena, ref_ident);
    const effect = try t.createBinOpNode(op, ref_deref, one_literal);

    switch (position) {
        .pre => {
            try block_scope.statements.append(t.gpa, effect);

            const break_node = try ZigTag.break_val.create(t.arena, .{
                .label = block_scope.label,
                .val = ref_deref,
            });
            try block_scope.statements.append(t.gpa, break_node);
        },
        .post => {
            const tmp = try block_scope.reserveMangledName("tmp");
            const tmp_decl = try ZigTag.var_simple.create(t.arena, .{ .name = tmp, .init = ref_deref });
            try block_scope.statements.append(t.gpa, tmp_decl);

            try block_scope.statements.append(t.gpa, effect);

            const tmp_ident = try ZigTag.identifier.create(t.arena, tmp);
            const break_node = try ZigTag.break_val.create(t.arena, .{
                .label = block_scope.label,
                .val = tmp_ident,
            });
            try block_scope.statements.append(t.gpa, break_node);
        },
    }

    return try block_scope.complete();
}

fn transPtrDiffExpr(t: *Translator, scope: *Scope, bin: Node.Binary) TransError!ZigNode {
    const lhs_uncasted = try t.transExpr(scope, bin.lhs, .used);
    const rhs_uncasted = try t.transExpr(scope, bin.rhs, .used);

    const lhs = try ZigTag.int_from_ptr.create(t.arena, lhs_uncasted);
    const rhs = try ZigTag.int_from_ptr.create(t.arena, rhs_uncasted);

    const sub_res = try t.createBinOpNode(.sub_wrap, lhs, rhs);

    // @divExact(@as(<platform-ptrdiff_t>, @bitCast(@intFromPtr(lhs)) -% @intFromPtr(rhs)), @sizeOf(<lhs target type>))
    const ptrdiff_type = try t.transTypeIntWidthOf(bin.qt, true);

    const bitcast = try ZigTag.as.create(t.arena, .{
        .lhs = ptrdiff_type,
        .rhs = try ZigTag.bit_cast.create(t.arena, sub_res),
    });

    // C standard requires that pointer subtraction operands are of the same type,
    // otherwise it is undefined behavior. So we can assume the left and right
    // sides are the same Type and arbitrarily choose left.
    const lhs_ty = try t.transType(scope, bin.lhs.qt(t.tree), bin.lhs.tok(t.tree));
    const c_pointer = t.getContainer(lhs_ty).?;

    if (c_pointer.castTag(.c_pointer)) |c_pointer_payload| {
        const sizeof = try ZigTag.sizeof.create(t.arena, c_pointer_payload.data.elem_type);
        return ZigTag.div_exact.create(t.arena, .{
            .lhs = bitcast,
            .rhs = sizeof,
        });
    } else {
        // This is an opaque/incomplete type. This subtraction exhibits Undefined Behavior by the C99 spec.
        // However, allowing subtraction on `void *` and function pointers is a commonly used extension.
        // So, just return the value in byte units, mirroring the behavior of this language extension as implemented by GCC and Clang.
        return bitcast;
    }
}

/// Translate an arithmetic expression with a pointer operand and a signed-integer operand.
/// Zig requires a usize argument for pointer arithmetic, so we intCast to isize and then
/// bitcast to usize; pointer wraparound makes the math work.
/// Zig pointer addition is not commutative (unlike C); the pointer operand needs to be on the left.
/// The + operator in C is not a sequence point so it should be safe to switch the order if necessary.
fn transPointerArithmeticSignedOp(t: *Translator, scope: *Scope, bin: Node.Binary, op_id: ZigTag) TransError!ZigNode {
    std.debug.assert(op_id == .add or op_id == .sub);

    const lhs_qt = bin.lhs.qt(t.tree);
    const swap_operands = op_id == .add and
        (lhs_qt.isInt(t.comp) and lhs_qt.signedness(t.comp) == .signed);

    const swizzled_lhs = if (swap_operands) bin.rhs else bin.lhs;
    const swizzled_rhs = if (swap_operands) bin.lhs else bin.rhs;

    const lhs_node = try t.transExpr(scope, swizzled_lhs, .used);
    const rhs_node = try t.transExpr(scope, swizzled_rhs, .used);

    const bitcast_node = try t.usizeCastForWrappingPtrArithmetic(rhs_node);

    return t.createBinOpNode(op_id, lhs_node, bitcast_node);
}

fn transMemberAccess(
    t: *Translator,
    scope: *Scope,
    kind: enum { normal, ptr },
    member_access: Node.MemberAccess,
) TransError!ZigNode {
    const base_info = switch (kind) {
        .normal => member_access.base.qt(t.tree),
        .ptr => member_access.base.qt(t.tree).childType(t.comp),
    };
    const record = base_info.getRecord(t.comp).?;
    const field = record.fields[member_access.member_index];
    const field_name = if (field.name_tok == 0) t.anonymous_record_field_names.get(.{
        .parent = base_info.base(t.comp).qt,
        .field = field.qt,
    }).? else field.name.lookup(t.comp);
    const base_node = try t.transExpr(scope, member_access.base, .used);
    const lhs = switch (kind) {
        .normal => base_node,
        .ptr => try ZigTag.deref.create(t.arena, base_node),
    };
    return ZigTag.field_access.create(t.arena, .{
        .lhs = lhs,
        .field_name = field_name,
    });
}

fn transArrayAccess(t: *Translator, scope: *Scope, array_access: Node.ArrayAccess) TransError!ZigNode {
    // Unwrap the base statement if it's an array decayed to a bare pointer type
    // so that we index the array itself
    const base = base: {
        const base = array_access.base.get(t.tree);
        if (base != .cast) break :base array_access.base;
        if (base.cast.kind != .array_to_pointer) break :base array_access.base;
        break :base base.cast.operand;
    };

    const base_node = try t.transExpr(scope, base, .used);
    const index = index: {
        const index = try t.transExpr(scope, array_access.index, .used);
        const index_qt = array_access.index.qt(t.tree);
        const maybe_bigger_than_usize = switch (index_qt.base(t.comp).type) {
            .bool => {
                break :index try ZigTag.int_from_bool.create(t.arena, index);
            },
            .int => |int| switch (int) {
                .long_long, .ulong_long, .int128, .uint128 => true,
                else => false,
            },
            .bit_int => |bit_int| bit_int.bits > t.comp.target.ptrBitWidth(),
            else => unreachable,
        };

        const is_nonnegative_int_literal = if (t.tree.value_map.get(array_access.index)) |val|
            val.compare(.gte, .zero, t.comp)
        else
            false;
        const is_signed = index_qt.signedness(t.comp) == .signed;

        if (is_signed and !is_nonnegative_int_literal) {
            // First cast to `isize` to get proper sign extension and
            // then @bitCast to `usize` to satisfy the compiler.
            const index_isize = try ZigTag.as.create(t.arena, .{
                .lhs = try ZigTag.type.create(t.arena, "isize"),
                .rhs = try ZigTag.int_cast.create(t.arena, index),
            });
            break :index try ZigTag.bit_cast.create(t.arena, index_isize);
        }

        if (maybe_bigger_than_usize) {
            break :index try ZigTag.int_cast.create(t.arena, index);
        }
        break :index index;
    };

    return ZigTag.array_access.create(t.arena, .{
        .lhs = base_node,
        .rhs = index,
    });
}

fn transBuiltinCall(
    t: *Translator,
    scope: *Scope,
    call: Node.BuiltinCall,
    used: ResultUsed,
) TransError!ZigNode {
    const builtin_name = t.tree.tokSlice(call.builtin_tok);
    const builtin = builtins.map.get(builtin_name) orelse
        return t.fail(error.UnsupportedTranslation, call.builtin_tok, "TODO implement function '{s}' in std.zig.c_builtins", .{builtin_name});

    if (builtin.tag) |tag| switch (tag) {
        .byte_swap, .ceil, .cos, .sin, .exp, .exp2, .exp10, .abs, .log, .log2, .log10, .round, .sqrt, .trunc, .floor => {
            assert(call.args.len == 1);
            const ptr = try t.arena.create(ast.Payload.UnOp);
            ptr.* = .{
                .base = .{ .tag = tag },
                .data = try t.transExprCoercing(scope, call.args[0], used),
            };
            return ZigNode.initPayload(&ptr.base);
        },
        .@"unreachable" => return ZigTag.@"unreachable".init(),
        else => unreachable,
    };

    // Overriding a builtin function is a hard error in C
    // so we do not need to worry about aliasing.
    try t.needed_builtins.put(t.gpa, builtin_name, builtin.source);

    const arg_nodes = try t.arena.alloc(ZigNode, call.args.len);
    for (call.args, arg_nodes) |c_arg, *zig_arg| {
        zig_arg.* = try t.transExprCoercing(scope, c_arg, used);
    }

    const res = try ZigTag.call.create(t.arena, .{
        .lhs = try ZigTag.identifier.create(t.arena, builtin_name),
        .args = arg_nodes,
    });
    if (call.qt.is(t.comp, .void)) return res;
    return t.maybeSuppressResult(used, res);
}

fn transCall(
    t: *Translator,
    scope: *Scope,
    call: Node.Call,
    used: ResultUsed,
) TransError!ZigNode {
    const raw_fn_expr = try t.transExpr(scope, call.callee, .used);
    const fn_expr = blk: {
        loop: switch (call.callee.get(t.tree)) {
            .paren_expr => |paren_expr| {
                continue :loop paren_expr.operand.get(t.tree);
            },
            .decl_ref_expr => |decl_ref| {
                if (decl_ref.qt.is(t.comp, .func)) break :blk raw_fn_expr;
            },
            .cast => |cast| {
                if (cast.kind == .function_to_pointer) {
                    continue :loop cast.operand.get(t.tree);
                }
            },
            .deref_expr, .addr_of_expr => |un| {
                continue :loop un.operand.get(t.tree);
            },
            .generic_expr => |generic| {
                continue :loop generic.chosen.get(t.tree);
            },
            else => {},
        }
        break :blk try ZigTag.unwrap.create(t.arena, raw_fn_expr);
    };

    const callee_qt = call.callee.qt(t.tree);
    const maybe_ptr_ty = callee_qt.get(t.comp, .pointer);
    const func_qt = if (maybe_ptr_ty) |ptr| ptr.child else callee_qt;
    const func_ty = func_qt.get(t.comp, .func).?;

    const arg_nodes = try t.arena.alloc(ZigNode, call.args.len);
    for (call.args, arg_nodes, 0..) |c_arg, *zig_arg, i| {
        if (i < func_ty.params.len) {
            zig_arg.* = try t.transExprCoercing(scope, c_arg, .used);

            if (zig_arg.isBoolRes() and !func_ty.params[i].qt.is(t.comp, .bool)) {
                // In C the result type of a boolean expression is int. If this result is passed as
                // an argument to a function whose parameter is also int, there is no cast. Therefore
                // in Zig we'll need to cast it from bool to u1 (which will safely coerce to c_int).
                zig_arg.* = try ZigTag.int_from_bool.create(t.arena, zig_arg.*);
            }
        } else {
            zig_arg.* = try t.transExpr(scope, c_arg, .used);

            if (zig_arg.isBoolRes()) {
                // Same as above but now we don't have a result type.
                const u1_node = try ZigTag.int_from_bool.create(t.arena, zig_arg.*);
                const c_int_node = try ZigTag.type.create(t.arena, "c_int");
                zig_arg.* = try ZigTag.as.create(t.arena, .{ .lhs = c_int_node, .rhs = u1_node });
            }
        }
    }

    const res = try ZigTag.call.create(t.arena, .{
        .lhs = fn_expr,
        .args = arg_nodes,
    });
    if (call.qt.is(t.comp, .void)) return res;
    return t.maybeSuppressResult(used, res);
}

const SuppressCast = enum { with_as, no_as };

fn transIntLiteral(
    t: *Translator,
    scope: *Scope,
    literal_index: Node.Index,
    used: ResultUsed,
    suppress_as: SuppressCast,
) TransError!ZigNode {
    const val = t.tree.value_map.get(literal_index).?;
    const int_lit_node = try t.createIntNode(val);
    if (suppress_as == .no_as) {
        return t.maybeSuppressResult(used, int_lit_node);
    }

    // Integer literals in C have types, and this can matter for several reasons.
    // For example, this is valid C:
    //     unsigned char y = 256;
    // How this gets evaluated is the 256 is an integer, which gets truncated to signed char, then bit-casted
    // to unsigned char, resulting in 0. In order for this to work, we have to emit this zig code:
    //     var y = @as(u8, @bitCast(@as(i8, @truncate(@as(c_int, 256)))));

    // @as(T, x)
    const ty_node = try t.transType(scope, literal_index.qt(t.tree), literal_index.tok(t.tree));
    const as = try ZigTag.as.create(t.arena, .{ .lhs = ty_node, .rhs = int_lit_node });
    return t.maybeSuppressResult(used, as);
}

fn transCharLiteral(
    t: *Translator,
    scope: *Scope,
    literal_index: Node.Index,
    used: ResultUsed,
    suppress_as: SuppressCast,
) TransError!ZigNode {
    const val = t.tree.value_map.get(literal_index).?;
    const char_literal = literal_index.get(t.tree).char_literal;
    const narrow = char_literal.kind == .ascii or char_literal.kind == .utf8;

    // C has a somewhat obscure feature called multi-character character constant
    // e.g. 'abcd'
    const int_value = val.toInt(u32, t.comp).?;
    const int_lit_node = if (char_literal.kind == .ascii and int_value > 255)
        try t.createNumberNode(int_value, .int)
    else
        try t.createCharLiteralNode(narrow, int_value);

    if (suppress_as == .no_as) {
        return t.maybeSuppressResult(used, int_lit_node);
    }

    // See comment in `transIntLiteral` for why this code is here.
    // @as(T, x)
    const as_node = try ZigTag.as.create(t.arena, .{
        .lhs = try t.transType(scope, char_literal.qt, char_literal.literal_tok),
        .rhs = int_lit_node,
    });
    return t.maybeSuppressResult(used, as_node);
}

fn transFloatLiteral(
    t: *Translator,
    scope: *Scope,
    literal_index: Node.Index,
    used: ResultUsed,
    suppress_as: SuppressCast,
) TransError!ZigNode {
    const val = t.tree.value_map.get(literal_index).?;
    const float_literal = literal_index.get(t.tree).float_literal;

    var buf: std.ArrayListUnmanaged(u8) = .empty;
    defer buf.deinit(t.gpa);
    const w = buf.writer(t.gpa);
    _ = try val.print(float_literal.qt, t.comp, w);

    const float_lit_node = try ZigTag.float_literal.create(t.arena, try t.arena.dupe(u8, buf.items));
    if (suppress_as == .no_as) {
        return t.maybeSuppressResult(used, float_lit_node);
    }

    const as_node = try ZigTag.as.create(t.arena, .{
        .lhs = try t.transType(scope, float_literal.qt, float_literal.literal_tok),
        .rhs = float_lit_node,
    });
    return t.maybeSuppressResult(used, as_node);
}

fn transCompoundLiteral(
    t: *Translator,
    scope: *Scope,
    literal: Node.CompoundLiteral,
    used: ResultUsed,
) TransError!ZigNode {
    if (used == .unused) {
        return t.transExpr(scope, literal.initializer, .unused);
    }

    // TODO taking a reference to a compound literal should result in a mutable
    // pointer (unless the literal is const).

    const initializer = try t.transExprCoercing(scope, literal.initializer, .used);
    const ty = try t.transType(scope, literal.qt, literal.l_paren_tok);
    if (!literal.thread_local and literal.storage_class != .static) {
        // In the simple case a compound literal can be translated
        // simply as `@as(type, initializer)`.
        return ZigTag.as.create(t.arena, .{ .lhs = ty, .rhs = initializer });
    }

    // Otherwise static or thread local compound literals are translated as
    // a reference to a variable wrapped in a struct.

    var block_scope = try Scope.Block.init(t, scope, true);
    defer block_scope.deinit();

    const tmp = try block_scope.reserveMangledName("tmp");
    const wrapped_name = "compound_literal";

    // const tmp = struct { var compound_literal = initializer };
    const temp_decl = try ZigTag.var_decl.create(t.arena, .{
        .is_pub = false,
        .is_const = literal.qt.@"const",
        .is_extern = false,
        .is_export = false,
        .is_threadlocal = literal.thread_local,
        .linksection_string = null,
        .alignment = null,
        .name = wrapped_name,
        .type = ty,
        .init = initializer,
    });
    const wrapped = try ZigTag.wrapped_local.create(t.arena, .{ .name = tmp, .init = temp_decl });
    try block_scope.statements.append(t.gpa, wrapped);

    // break :blk tmp.compound_literal
    const static_tmp_ident = try ZigTag.identifier.create(t.arena, tmp);
    const field_access = try ZigTag.field_access.create(t.arena, .{
        .lhs = static_tmp_ident,
        .field_name = wrapped_name,
    });
    const break_node = try ZigTag.break_val.create(t.arena, .{
        .label = block_scope.label,
        .val = field_access,
    });
    try block_scope.statements.append(t.gpa, break_node);

    return block_scope.complete();
}

fn transDefaultInit(
    t: *Translator,
    scope: *Scope,
    default_init: Node.DefaultInit,
    used: ResultUsed,
    suppress_as: SuppressCast,
) TransError!ZigNode {
    assert(used == .used);
    const type_node = try t.transType(scope, default_init.qt, default_init.last_tok);
    return try t.createZeroValueNode(default_init.qt, type_node, suppress_as);
}

fn transArrayInit(
    t: *Translator,
    scope: *Scope,
    array_init: Node.ContainerInit,
    used: ResultUsed,
) TransError!ZigNode {
    assert(used == .used);
    const array_item_qt = array_init.container_qt.childType(t.comp);
    const array_item_type = try t.transType(scope, array_item_qt, array_init.l_brace_tok);
    var maybe_lhs: ?ZigNode = null;
    var val_list: std.ArrayListUnmanaged(ZigNode) = .empty;
    defer val_list.deinit(t.gpa);
    var i: usize = 0;
    while (i < array_init.items.len) {
        const rhs = switch (array_init.items[i].get(t.tree)) {
            .array_filler_expr => |array_filler| blk: {
                const node = try ZigTag.array_filler.create(t.arena, .{
                    .type = array_item_type,
                    .filler = try t.createZeroValueNode(array_item_qt, array_item_type, .no_as),
                    .count = @intCast(array_filler.count),
                });
                i += 1;
                break :blk node;
            },
            else => blk: {
                defer val_list.clearRetainingCapacity();
                while (i < array_init.items.len) : (i += 1) {
                    if (array_init.items[i].get(t.tree) == .array_filler_expr) break;
                    const expr = try t.transExprCoercing(scope, array_init.items[i], .used);
                    try val_list.append(t.gpa, expr);
                }
                const array_type = try ZigTag.array_type.create(t.arena, .{
                    .elem_type = array_item_type,
                    .len = val_list.items.len,
                });
                const array_init_node = try ZigTag.array_init.create(t.arena, .{
                    .cond = array_type,
                    .cases = try t.arena.dupe(ZigNode, val_list.items),
                });
                break :blk array_init_node;
            },
        };
        maybe_lhs = if (maybe_lhs) |lhs| blk: {
            const cat = try ZigTag.array_cat.create(t.arena, .{
                .lhs = lhs,
                .rhs = rhs,
            });
            break :blk cat;
        } else rhs;
    }
    return maybe_lhs orelse try ZigTag.container_init_dot.create(t.arena, &.{});
}

fn transUnionInit(
    t: *Translator,
    scope: *Scope,
    union_init: Node.UnionInit,
    used: ResultUsed,
) TransError!ZigNode {
    assert(used == .used);
    const init_expr = union_init.initializer orelse
        return ZigTag.undefined_literal.init();

    if (init_expr.get(t.tree) == .default_init_expr) {
        return try t.transExpr(scope, init_expr, used);
    }

    const union_type = try t.transType(scope, union_init.union_qt, union_init.l_brace_tok);
    const field_init = try t.arena.create(ast.Payload.ContainerInit.Initializer);
    const field = union_init.union_qt.base(t.comp).type.@"union".fields[union_init.field_index];
    field_init.* = .{
        .name = field.name.lookup(t.comp),
        .value = try t.transExprCoercing(scope, init_expr, .used),
    };
    const container_init = try ZigTag.container_init.create(t.arena, .{
        .lhs = union_type,
        .inits = field_init[0..1],
    });
    return container_init;
}

fn transStructInit(
    t: *Translator,
    scope: *Scope,
    struct_init: Node.ContainerInit,
    used: ResultUsed,
) TransError!ZigNode {
    assert(used == .used);
    const struct_type = try t.transType(scope, struct_init.container_qt, struct_init.l_brace_tok);
    const field_inits = try t.arena.alloc(ast.Payload.ContainerInit.Initializer, struct_init.items.len);

    for (
        field_inits,
        struct_init.items,
        struct_init.container_qt.base(t.comp).type.@"struct".fields,
    ) |*init, field_expr, field| {
        init.* = .{
            .name = field.name.lookup(t.comp),
            .value = try t.transExprCoercing(scope, field_expr, .used),
        };
    }

    const container_init = try ZigTag.container_init.create(t.arena, .{
        .lhs = struct_type,
        .inits = field_inits,
    });
    return container_init;
}

fn transTypeInfo(
    t: *Translator,
    scope: *Scope,
    op: ZigTag,
    typeinfo: Node.TypeInfo,
) TransError!ZigNode {
    const operand = operand: {
        if (typeinfo.expr) |expr| {
            const operand = try t.transExpr(scope, expr, .used);
            break :operand try ZigTag.typeof.create(t.arena, operand);
        }
        break :operand try t.transType(scope, typeinfo.operand_qt, typeinfo.op_tok);
    };

    const payload = try t.arena.create(ast.Payload.UnOp);
    payload.* = .{
        .base = .{ .tag = op },
        .data = operand,
    };
    return ZigNode.initPayload(&payload.base);
}

fn transStmtExpr(
    t: *Translator,
    scope: *Scope,
    stmt_expr: Node.Unary,
    used: ResultUsed,
) TransError!ZigNode {
    const compound_stmt = stmt_expr.operand.get(t.tree).compound_stmt;
    if (used == .unused) {
        return t.transCompoundStmt(scope, compound_stmt);
    }
    var block_scope = try Scope.Block.init(t, scope, true);
    defer block_scope.deinit();

    for (compound_stmt.body[0 .. compound_stmt.body.len - 1]) |stmt| {
        const result = try t.transStmt(&block_scope.base, stmt);
        switch (result.tag()) {
            .declaration, .empty_block => {},
            else => try block_scope.statements.append(t.gpa, result),
        }
    }

    const last_result = try t.transExpr(&block_scope.base, compound_stmt.body[compound_stmt.body.len - 1], .used);
    switch (last_result.tag()) {
        .declaration, .empty_block => {},
        else => {
            const break_node = try ZigTag.break_val.create(t.arena, .{
                .label = block_scope.label,
                .val = last_result,
            });
            try block_scope.statements.append(t.gpa, break_node);
        },
    }
    return block_scope.complete();
}

// =====================
// Node creation helpers
// =====================

fn createZeroValueNode(
    t: *Translator,
    qt: QualType,
    type_node: ZigNode,
    suppress_as: SuppressCast,
) !ZigNode {
    switch (qt.base(t.comp).type) {
        .bool => return ZigTag.false_literal.init(),
        .int, .bit_int, .float => {
            const zero_literal = ZigTag.zero_literal.init();
            return switch (suppress_as) {
                .with_as => try t.createBinOpNode(.as, type_node, zero_literal),
                .no_as => zero_literal,
            };
        },
        .pointer => {
            const null_literal = ZigTag.null_literal.init();
            return switch (suppress_as) {
                .with_as => try t.createBinOpNode(.as, type_node, null_literal),
                .no_as => null_literal,
            };
        },
        else => {},
    }
    return try ZigTag.std_mem_zeroes.create(t.arena, type_node);
}

fn createIntNode(t: *Translator, int: aro.Value) !ZigNode {
    var space: aro.Interner.Tag.Int.BigIntSpace = undefined;
    var big = t.comp.interner.get(int.ref()).toBigInt(&space);
    const is_negative = !big.positive;
    big.positive = true;

    const str = big.toStringAlloc(t.arena, 10, .lower) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
    };
    const res = try ZigTag.integer_literal.create(t.arena, str);
    if (is_negative) return ZigTag.negate.create(t.arena, res);
    return res;
}

fn createNumberNode(t: *Translator, num: anytype, num_kind: enum { int, float }) !ZigNode {
    const fmt_s = switch (@typeInfo(@TypeOf(num))) {
        .int, .comptime_int => "{d}",
        else => "{s}",
    };
    const str = try std.fmt.allocPrint(t.arena, fmt_s, .{num});
    if (num_kind == .float)
        return ZigTag.float_literal.create(t.arena, str)
    else
        return ZigTag.integer_literal.create(t.arena, str);
}

fn createCharLiteralNode(t: *Translator, narrow: bool, val: u32) TransError!ZigNode {
    return ZigTag.char_literal.create(t.arena, if (narrow)
        try std.fmt.allocPrint(t.arena, "'{'}'", .{std.zig.fmtEscapes(&.{@as(u8, @intCast(val))})})
    else
        try std.fmt.allocPrint(t.arena, "'\\u{{{x}}}'", .{val}));
}

fn createBinOpNode(
    t: *Translator,
    op: ZigTag,
    lhs: ZigNode,
    rhs: ZigNode,
) !ZigNode {
    const payload = try t.arena.create(ast.Payload.BinOp);
    payload.* = .{
        .base = .{ .tag = op },
        .data = .{
            .lhs = lhs,
            .rhs = rhs,
        },
    };
    return ZigNode.initPayload(&payload.base);
}

fn createHelperCallNode(t: *Translator, name: std.meta.DeclEnum(helpers.sources), args: []const ZigNode) !ZigNode {
    switch (name) {
        .div => {
            try t.needed_helpers.put(t.gpa, "ArithmeticConversion", helpers.sources.ArithmeticConversion);
            try t.needed_helpers.put(t.gpa, "cast", helpers.sources.cast);
            try t.needed_helpers.put(t.gpa, "div", helpers.sources.div);
        },
        .rem => {
            try t.needed_helpers.put(t.gpa, "ArithmeticConversion", helpers.sources.ArithmeticConversion);
            try t.needed_helpers.put(t.gpa, "cast", helpers.sources.cast);
            try t.needed_helpers.put(t.gpa, "signedRemainder", helpers.sources.signedRemainder);
            try t.needed_helpers.put(t.gpa, "rem", helpers.sources.rem);
        },
        .CAST_OR_CALL => {
            try t.needed_helpers.put(t.gpa, "cast", helpers.sources.cast);
            try t.needed_helpers.put(t.gpa, "CAST_OR_CALL", helpers.sources.CAST_OR_CALL);
        },
        .L_SUFFIX => {
            try t.needed_helpers.put(t.gpa, "promoteIntLiteral", helpers.sources.promoteIntLiteral);
            try t.needed_helpers.put(t.gpa, "L_SUFFIX", helpers.sources.L_SUFFIX);
        },
        .LL_SUFFIX => {
            try t.needed_helpers.put(t.gpa, "promoteIntLiteral", helpers.sources.promoteIntLiteral);
            try t.needed_helpers.put(t.gpa, "LL_SUFFIX", helpers.sources.LL_SUFFIX);
        },
        .U_SUFFIX => {
            try t.needed_helpers.put(t.gpa, "promoteIntLiteral", helpers.sources.promoteIntLiteral);
            try t.needed_helpers.put(t.gpa, "U_SUFFIX", helpers.sources.U_SUFFIX);
        },
        .UL_SUFFIX => {
            try t.needed_helpers.put(t.gpa, "promoteIntLiteral", helpers.sources.promoteIntLiteral);
            try t.needed_helpers.put(t.gpa, "UL_SUFFIX", helpers.sources.UL_SUFFIX);
        },
        .ULL_SUFFIX => {
            try t.needed_helpers.put(t.gpa, "promoteIntLiteral", helpers.sources.promoteIntLiteral);
            try t.needed_helpers.put(t.gpa, "ULL_SUFFIX", helpers.sources.ULL_SUFFIX);
        },
        inline else => |tag| {
            try t.needed_helpers.put(t.gpa, @tagName(tag), @field(helpers.sources, @tagName(tag)));
        },
    }

    return ZigTag.helper_call.create(t.arena, .{
        .name = @tagName(name),
        .args = try t.arena.dupe(ZigNode, args),
    });
}

/// Cast a signed integer node to a usize, for use in pointer arithmetic. Negative numbers
/// will become very large positive numbers but that is ok since we only use this in
/// pointer arithmetic expressions, where wraparound will ensure we get the correct value.
/// node -> @as(usize, @bitCast(@as(isize, @intCast(node))))
fn usizeCastForWrappingPtrArithmetic(t: *Translator, node: ZigNode) TransError!ZigNode {
    const intcast_node = try ZigTag.as.create(t.arena, .{
        .lhs = try ZigTag.type.create(t.arena, "isize"),
        .rhs = try ZigTag.int_cast.create(t.arena, node),
    });

    return ZigTag.as.create(t.arena, .{
        .lhs = try ZigTag.type.create(t.arena, "usize"),
        .rhs = try ZigTag.bit_cast.create(t.arena, intcast_node),
    });
}

// =================
// Macro translation
// =================

fn transMacros(t: *Translator) !void {
    var tok_list = std.ArrayList(CToken).init(t.gpa);
    defer tok_list.deinit();

    var it = t.pp.defines.iterator();
    while (it.next()) |define_kv| {
        const name = define_kv.key_ptr.*;
        const macro = define_kv.value_ptr.*;

        if (t.global_scope.containsNow(name)) {
            continue;
        }

        // TODO bug in Aro
        const params = if (macro.is_func) macro.params else &.{};
        if (t.checkTranslatableMacro(macro.tokens, params)) |err| switch (err) {
            .undefined_identifier => |ident| return t.failDeclExtra(macro.loc, name, "unable to translate macro: undefined identifier `{s}`", .{ident}),
            .invalid_arg_usage => |ident| return t.failDeclExtra(macro.loc, name, "unable to translate macro: untranslatable usage of arg `{s}`", .{ident}),
        };

        tok_list.items.len = 0;
        try tok_list.ensureUnusedCapacity(macro.tokens.len);
        for (macro.tokens) |tok| {
            switch (tok.id) {
                .invalid => continue,
                .whitespace => continue,
                else => {},
            }
            tok_list.appendAssumeCapacity(tok);
        }

        var macro_translator: MacroTranslator = .{
            .t = t,
            .tokens = tok_list.items,
            .name = name,
            .macro = macro,
        };

        const res = if (macro.is_func)
            macro_translator.transFnMacro()
        else
            macro_translator.transMacro();
        res catch |err| switch (err) {
            error.ParseError => continue,
            error.OutOfMemory => |e| return e,
        };
    }
}

const MacroTranslateError = union(enum) {
    undefined_identifier: []const u8,
    invalid_arg_usage: []const u8,
};

fn checkTranslatableMacro(t: *Translator, tokens: []const CToken, params: []const []const u8) ?MacroTranslateError {
    var last_is_type_kw = false;
    var i: usize = 0;
    while (i < tokens.len) : (i += 1) {
        const token = tokens[i];
        switch (token.id) {
            .period, .arrow => i += 1, // skip next token since field identifiers can be unknown
            .keyword_struct, .keyword_union, .keyword_enum => if (!last_is_type_kw) {
                last_is_type_kw = true;
                continue;
            },
            .identifier, .extended_identifier => {
                const identifier = t.pp.tokSlice(token);
                const is_param = for (params) |param| {
                    if (mem.eql(u8, identifier, param)) break true;
                } else false;
                if (is_param and last_is_type_kw) {
                    return .{ .invalid_arg_usage = identifier };
                }
                if (!t.global_scope.contains(identifier) and !builtins.map.has(identifier) and !is_param) {
                    return .{ .undefined_identifier = identifier };
                }
            },
            else => {},
        }
        last_is_type_kw = false;
    }
    return null;
}

fn getContainer(t: *Translator, node: ZigNode) ?ZigNode {
    switch (node.tag()) {
        .@"union",
        .@"struct",
        .address_of,
        .bit_not,
        .not,
        .optional_type,
        .negate,
        .negate_wrap,
        .array_type,
        .c_pointer,
        .single_pointer,
        => return node,

        .identifier => {
            const ident = node.castTag(.identifier).?;
            if (t.global_scope.sym_table.get(ident.data)) |value| {
                if (value.castTag(.var_decl)) |var_decl|
                    return t.getContainer(var_decl.data.init.?);
                if (value.castTag(.var_simple) orelse value.castTag(.pub_var_simple)) |var_decl|
                    return t.getContainer(var_decl.data.init);
            }
        },

        .field_access => {
            const field_access = node.castTag(.field_access).?;

            if (t.getContainerTypeOf(field_access.data.lhs)) |ty_node| {
                if (ty_node.castTag(.@"struct") orelse ty_node.castTag(.@"union")) |container| {
                    for (container.data.fields) |field| {
                        if (mem.eql(u8, field.name, field_access.data.field_name)) {
                            return t.getContainer(field.type);
                        }
                    }
                }
            }
        },

        else => {},
    }
    return null;
}

fn getContainerTypeOf(t: *Translator, ref: ZigNode) ?ZigNode {
    if (ref.castTag(.identifier)) |ident| {
        if (t.global_scope.sym_table.get(ident.data)) |value| {
            if (value.castTag(.var_decl)) |var_decl| {
                return t.getContainer(var_decl.data.type);
            }
        }
    } else if (ref.castTag(.field_access)) |field_access| {
        if (t.getContainerTypeOf(field_access.data.lhs)) |ty_node| {
            if (ty_node.castTag(.@"struct") orelse ty_node.castTag(.@"union")) |container| {
                for (container.data.fields) |field| {
                    if (mem.eql(u8, field.name, field_access.data.field_name)) {
                        return t.getContainer(field.type);
                    }
                }
            } else return ty_node;
        }
    }
    return null;
}

fn getFnProto(t: *Translator, ref: ZigNode) ?*ast.Payload.Func {
    const init = if (ref.castTag(.var_decl)) |v|
        v.data.init orelse return null
    else if (ref.castTag(.var_simple) orelse ref.castTag(.pub_var_simple)) |v|
        v.data.init
    else
        return null;
    if (t.getContainerTypeOf(init)) |ty_node| {
        if (ty_node.castTag(.optional_type)) |prefix| {
            if (prefix.data.castTag(.single_pointer)) |sp| {
                if (sp.data.elem_type.castTag(.func)) |fn_proto| {
                    return fn_proto;
                }
            }
        }
    }
    return null;
}
