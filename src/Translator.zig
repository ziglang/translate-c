const std = @import("std");
const mem = std.mem;
const assert = std.debug.assert;
const CallingConvention = std.builtin.CallingConvention;

const aro = @import("aro");
const CToken = aro.Tokenizer.Token;
const Tree = aro.Tree;
const NodeIndex = Tree.NodeIndex;
const TokenIndex = Tree.TokenIndex;
const Type = aro.Type;

const ast = @import("ast.zig");
const ZigNode = ast.Node;
const ZigTag = ZigNode.Tag;
const builtins = @import("builtins.zig");
const Scope = @import("Scope.zig");

const Translator = @This();

pub const Error = std.mem.Allocator.Error;
pub const MacroProcessingError = Error || error{UnexpectedMacroToken};
pub const TypeError = Error || error{UnsupportedType};
pub const TransError = TypeError || error{UnsupportedTranslation};

gpa: mem.Allocator,
arena: mem.Allocator,
decl_table: std.AutoArrayHashMapUnmanaged(usize, []const u8) = .empty,
alias_list: Scope.AliasList,
global_scope: *Scope.Root,
mangle_count: u32 = 0,
/// Table of record decls that have been demoted to opaques.
opaque_demotes: std.AutoHashMapUnmanaged(usize, void) = .empty,
/// Table of unnamed enums and records that are child types of typedefs.
unnamed_typedefs: std.AutoHashMapUnmanaged(usize, []const u8) = .empty,
/// Needed to decide if we are parsing a typename
typedefs: std.StringArrayHashMapUnmanaged(void) = .empty,

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

pattern_list: PatternList,
tree: Tree,
comp: *aro.Compilation,
mapper: aro.TypeMapper,

rendered_builtins: std.StringHashMapUnmanaged(void) = .{},
render_buf: std.ArrayList(u8),

fn getMangle(t: *Translator) u32 {
    t.mangle_count += 1;
    return t.mangle_count;
}

/// Convert an aro TokenIndex to a 'file:line:column' string
fn locStr(t: *Translator, tok_idx: TokenIndex) ![]const u8 {
    const token_loc = t.tree.tokens.items(.loc)[tok_idx];
    const source = t.comp.getSource(token_loc.id);
    const line_col = source.lineCol(token_loc);
    const filename = source.path;

    const line = source.physicalLine(token_loc);
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

fn failDecl(t: *Translator, loc: TokenIndex, name: []const u8, comptime format: []const u8, args: anytype) Error!void {
    // location
    // pub const name = @compileError(msg);
    const fail_msg = try std.fmt.allocPrint(t.arena, format, args);
    try t.addTopLevelDecl(name, try ZigTag.fail_decl.create(t.arena, .{ .actual = name, .mangled = fail_msg }));
    const str = try t.locStr(loc);
    const location_comment = try std.fmt.allocPrint(t.arena, "// {s}", .{str});
    try t.global_scope.nodes.append(t.gpa, try ZigTag.warning.create(t.arena, location_comment));
}

fn warn(t: *Translator, scope: *Scope, loc: TokenIndex, comptime format: []const u8, args: anytype) !void {
    const str = try t.locStr(loc);
    const value = try std.fmt.allocPrint(t.arena, "// {s}: warning: " ++ format, .{str} ++ args);
    try scope.appendNode(try ZigTag.warning.create(t.arena, value));
}

fn nodeLoc(t: *Translator, node: NodeIndex) TokenIndex {
    const token_index = t.tree.nodes.items(.loc)[@intFromEnum(node)];
    return switch (token_index) {
        .none => unreachable,
        else => @intFromEnum(token_index),
    };
}

fn nodeTag(t: *Translator, node: NodeIndex) Tree.Tag {
    return t.tree.nodes.items(.tag)[@intFromEnum(node)];
}

fn nodeType(t: *Translator, node: NodeIndex) Type {
    return t.tree.nodes.items(.ty)[@intFromEnum(node)];
}

fn nodeData(t: *Translator, node: NodeIndex) Tree.Node.Data {
    return t.tree.nodes.items(.data)[@intFromEnum(node)];
}

pub fn translate(
    gpa: mem.Allocator,
    comp: *aro.Compilation,
    tree: aro.Tree,
) ![]u8 {
    const mapper = tree.comp.string_interner.getFastTypeMapper(tree.comp.gpa) catch tree.comp.string_interner.getSlowTypeMapper();
    defer mapper.deinit(tree.comp.gpa);

    var arena_allocator = std.heap.ArenaAllocator.init(gpa);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    var translator: Translator = .{
        .gpa = gpa,
        .arena = arena,
        .alias_list = .empty,
        .global_scope = try arena.create(Scope.Root),
        .pattern_list = try PatternList.init(gpa),
        .comp = comp,
        .mapper = mapper,
        .tree = tree,
        .render_buf = .init(gpa),
    };
    translator.global_scope.* = Scope.Root.init(&translator);
    defer {
        translator.decl_table.deinit(gpa);
        translator.alias_list.deinit(gpa);
        translator.global_names.deinit(gpa);
        translator.weak_global_names.deinit(gpa);
        translator.opaque_demotes.deinit(gpa);
        translator.unnamed_typedefs.deinit(gpa);
        translator.typedefs.deinit(gpa);
        translator.global_scope.deinit();
        translator.pattern_list.deinit(gpa);
        translator.render_buf.deinit();
        translator.rendered_builtins.deinit(gpa);
    }

    try prepopulateGlobalNameTable(&translator);
    try transTopLevelDecls(&translator);

    for (translator.alias_list.items) |alias| {
        if (!translator.global_scope.sym_table.contains(alias.alias)) {
            const node = try ZigTag.alias.create(arena, .{ .actual = alias.alias, .mangled = alias.name });
            try addTopLevelDecl(&translator, alias.alias, node);
        }
    }

    var zig_ast = try ast.render(gpa, translator.global_scope.nodes.items);
    defer {
        gpa.free(zig_ast.source);
        zig_ast.deinit(gpa);
    }
    try zig_ast.renderToArrayList(&translator.render_buf, .{});
    return translator.render_buf.toOwnedSlice();
}

fn prepopulateGlobalNameTable(t: *Translator) !void {
    const node_tags = t.tree.nodes.items(.tag);
    const node_types = t.tree.nodes.items(.ty);
    const node_data = t.tree.nodes.items(.data);
    for (t.tree.root_decls) |node| {
        const data = node_data[@intFromEnum(node)];
        switch (node_tags[@intFromEnum(node)]) {
            .typedef => {},

            .struct_decl_two,
            .union_decl_two,
            .struct_decl,
            .union_decl,
            .struct_forward_decl,
            .union_forward_decl,
            .enum_decl_two,
            .enum_decl,
            .enum_forward_decl,
            => {
                const raw_ty = node_types[@intFromEnum(node)];
                const ty = raw_ty.canonicalize(.standard);
                const name_id = if (ty.isRecord()) ty.data.record.name else ty.data.@"enum".name;
                const decl_name = t.mapper.lookup(name_id);
                const container_prefix = if (ty.is(.@"struct")) "struct" else if (ty.is(.@"union")) "union" else "enum";
                const prefixed_name = try std.fmt.allocPrint(t.arena, "{s}_{s}", .{ container_prefix, decl_name });
                // `decl_name` and `prefixed_name` are the preferred names for this type.
                // However, we can name it anything else if necessary, so these are "weak names".
                try t.weak_global_names.ensureUnusedCapacity(t.gpa, 2);
                t.weak_global_names.putAssumeCapacity(decl_name, {});
                t.weak_global_names.putAssumeCapacity(prefixed_name, {});
            },

            .fn_proto,
            .static_fn_proto,
            .inline_fn_proto,
            .inline_static_fn_proto,
            .fn_def,
            .static_fn_def,
            .inline_fn_def,
            .inline_static_fn_def,
            .@"var",
            .extern_var,
            .static_var,
            .threadlocal_var,
            .threadlocal_extern_var,
            .threadlocal_static_var,
            => {
                const decl_name = t.tree.tokSlice(data.decl.name);
                try t.global_names.put(t.gpa, decl_name, {});
            },
            .static_assert => {},
            else => unreachable,
        }
    }
}

// =======================
// Declaration translation
// =======================

fn transTopLevelDecls(t: *Translator) !void {
    for (t.tree.root_decls) |node| {
        try t.transDecl(&t.global_scope.base, node);
    }
}

fn transDecl(t: *Translator, scope: *Scope, decl: NodeIndex) !void {
    switch (t.nodeTag(decl)) {
        .typedef => {
            try t.transTypeDef(scope, decl);
        },

        .struct_decl_two,
        .union_decl_two,
        .struct_decl,
        .union_decl,
        => {
            try t.transRecordDecl(scope, t.nodeType(decl));
        },

        .enum_decl_two, .enum_decl => {
            const fields = t.tree.childNodes(decl);
            const enum_decl = t.nodeType(decl).canonicalize(.standard).data.@"enum";
            try t.transEnumDecl(scope, enum_decl, fields, t.nodeLoc(decl));
        },

        .enum_field_decl,
        .record_field_decl,
        .indirect_record_field_decl,
        .struct_forward_decl,
        .union_forward_decl,
        .enum_forward_decl,
        => return,

        .fn_proto,
        .static_fn_proto,
        .inline_fn_proto,
        .inline_static_fn_proto,
        .fn_def,
        .static_fn_def,
        .inline_fn_def,
        .inline_static_fn_def,
        => {
            try t.transFnDecl(decl, true);
        },

        .@"var",
        .extern_var,
        .static_var,
        .threadlocal_var,
        .threadlocal_extern_var,
        .threadlocal_static_var,
        => {
            try t.transVarDecl(decl);
        },
        .static_assert => {
            try t.transStaticAssert(&t.global_scope.base, decl);
        },
        else => unreachable,
    }
}

fn transTypeDef(t: *Translator, scope: *Scope, typedef_decl: NodeIndex) Error!void {
    const ty = t.nodeType(typedef_decl);
    const decl = t.nodeData(typedef_decl).decl;

    const toplevel = scope.id == .root;
    const bs: *Scope.Block = if (!toplevel) try scope.findBlockScope(t) else undefined;

    var name: []const u8 = t.tree.tokSlice(decl.name);
    try t.typedefs.put(t.gpa, name, {});

    if (!toplevel) name = try bs.makeMangledName(name);

    const typedef_loc = decl.name;
    const init_node = t.transType(scope, ty, .standard, typedef_loc) catch |err| switch (err) {
        error.UnsupportedType => {
            return t.failDecl(typedef_loc, name, "unable to resolve typedef child type", .{});
        },
        error.OutOfMemory => |e| return e,
    };

    const payload = try t.arena.create(ast.Payload.SimpleVarDecl);
    payload.* = .{
        .base = .{ .tag = ([2]ZigTag{ .var_simple, .pub_var_simple })[@intFromBool(toplevel)] },
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
        if (node.tag() != .pub_var_simple) {
            try bs.discardVariable(name);
        }
    }
}

fn mangleWeakGlobalName(t: *Translator, want_name: []const u8) ![]const u8 {
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

fn transRecordDecl(t: *Translator, scope: *Scope, record_ty: Type) Error!void {
    const record_decl = record_ty.getRecord().?;
    if (t.decl_table.get(@intFromPtr(record_decl))) |_|
        return; // Avoid processing this decl twice
    const toplevel = scope.id == .root;
    const bs: *Scope.Block = if (!toplevel) try scope.findBlockScope(t) else undefined;

    const container_kind: ZigTag = if (record_ty.is(.@"union")) .@"union" else .@"struct";
    const container_kind_name = @tagName(container_kind);

    var bare_name = t.mapper.lookup(record_decl.name);
    const is_unnamed = bare_name[0] == '(';
    var name = bare_name;

    if (t.unnamed_typedefs.get(@intFromPtr(record_decl))) |typedef_name| {
        bare_name = typedef_name;
        name = typedef_name;
    } else {
        if (record_ty.isAnonymousRecord(t.comp)) {
            bare_name = try std.fmt.allocPrint(t.arena, "unnamed_{d}", .{t.getMangle()});
        }
        name = try std.fmt.allocPrint(t.arena, "{s}_{s}", .{ container_kind_name, bare_name });
        if (toplevel and !is_unnamed) {
            name = try t.mangleWeakGlobalName(name);
        }
    }
    if (!toplevel) name = try bs.makeMangledName(name);
    try t.decl_table.putNoClobber(t.gpa, @intFromPtr(record_decl), name);

    const is_pub = toplevel and !is_unnamed;
    const init_node = blk: {
        if (record_decl.isIncomplete()) {
            try t.opaque_demotes.put(t.gpa, @intFromPtr(record_decl), {});
            break :blk ZigTag.opaque_literal.init();
        }

        var fields = try std.ArrayList(ast.Payload.Record.Field).initCapacity(t.gpa, record_decl.fields.len);
        defer fields.deinit();

        // TODO: Add support for flexible array field functions
        var functions = std.ArrayList(ZigNode).init(t.gpa);
        defer functions.deinit();

        var unnamed_field_count: u32 = 0;

        // If a record doesn't have any attributes that would affect the alignment and
        // layout, then we can just use a simple `extern` type. If it does have attributes,
        // then we need to inspect the layout and assign an `align` value for each field.
        const has_alignment_attributes = record_decl.field_attributes != null or
            record_ty.hasAttribute(.@"packed") or
            record_ty.hasAttribute(.aligned);
        const head_field_alignment: ?c_uint = if (has_alignment_attributes) headFieldAlignment(record_decl) else null;

        for (record_decl.fields, 0..) |field, field_index| {
            const field_loc = field.name_tok;

            // Demote record to opaque if it contains a bitfield
            if (!field.isRegularField()) {
                try t.opaque_demotes.put(t.gpa, @intFromPtr(record_decl), {});
                try t.warn(scope, field_loc, "{s} demoted to opaque type - has bitfield", .{container_kind_name});
                break :blk ZigTag.opaque_literal.init();
            }

            var field_name = t.mapper.lookup(field.name);
            if (!field.isNamed()) {
                field_name = try std.fmt.allocPrint(t.arena, "unnamed_{d}", .{unnamed_field_count});
                unnamed_field_count += 1;
            }
            const field_type = t.transType(scope, field.ty, .preserve_quals, field_loc) catch |err| switch (err) {
                error.UnsupportedType => {
                    try t.opaque_demotes.put(t.gpa, @intFromPtr(record_decl), {});
                    try t.warn(scope, field.name_tok, "{s} demoted to opaque type - unable to translate type of field {s}", .{
                        container_kind_name,
                        field_name,
                    });
                    break :blk ZigTag.opaque_literal.init();
                },
                else => |e| return e,
            };

            const field_alignment = if (has_alignment_attributes)
                alignmentForField(record_decl, head_field_alignment, field_index)
            else
                null;

            // C99 introduced designated initializers for structs. Omitted fields are implicitly
            // initialized to zero. Some C APIs are designed with this in mind. Defaulting to zero
            // values for translated struct fields permits Zig code to comfortably use such an API.
            const default_value = if (container_kind == .@"struct")
                try ZigTag.std_mem_zeroes.create(t.arena, field_type)
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
        break :blk ZigNode.initPayload(&record_payload.base);
    };

    const payload = try t.arena.create(ast.Payload.SimpleVarDecl);
    payload.* = .{
        .base = .{ .tag = ([2]ZigTag{ .var_simple, .pub_var_simple })[@intFromBool(is_pub)] },
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
        if (node.tag() != .pub_var_simple) {
            try bs.discardVariable(name);
        }
    }
}

fn transFnDecl(t: *Translator, fn_decl_node: NodeIndex, is_pub: bool) Error!void {
    const raw_ty = t.nodeType(fn_decl_node);
    const fn_ty = raw_ty.canonicalize(.standard);
    const decl = t.nodeData(fn_decl_node).decl;
    if (t.decl_table.get(@intFromPtr(fn_ty.data.func))) |_|
        return; // Avoid processing this decl twice

    // TODO if this is a prototype for which a definition exists,
    // that definition should be translated instead.
    const fn_name = t.tree.tokSlice(decl.name);
    if (t.global_scope.sym_table.contains(fn_name))
        return; // Avoid processing this decl twice

    const fn_decl_loc = t.nodeLoc(fn_decl_node);
    const has_body = decl.node != .none;
    const is_always_inline = has_body and raw_ty.getAttribute(.always_inline) != null;
    const proto_ctx = FnProtoContext{
        .fn_name = fn_name,
        .is_inline = is_always_inline,
        .is_extern = !has_body,
        .is_export = switch (t.nodeTag(fn_decl_node)) {
            .fn_proto, .fn_def => has_body and !is_always_inline,

            .inline_fn_proto, .inline_fn_def, .inline_static_fn_proto, .inline_static_fn_def, .static_fn_proto, .static_fn_def => false,

            else => unreachable,
        },
        .is_pub = is_pub,
    };

    const proto_node = t.transFnType(&t.global_scope.base, raw_ty, fn_ty, fn_decl_loc, proto_ctx) catch |err| switch (err) {
        error.UnsupportedType => {
            return t.failDecl(fn_decl_loc, fn_name, "unable to resolve prototype of function", .{});
        },
        error.OutOfMemory => |e| return e,
    };

    if (!has_body) {
        return t.addTopLevelDecl(fn_name, proto_node);
    }
    const proto_payload = proto_node.castTag(.func).?;

    // actual function definition with body
    const body_stmt = decl.node;
    var block_scope = try Scope.Block.init(t, &t.global_scope.base, false);
    block_scope.return_type = fn_ty.data.func.return_type;
    defer block_scope.deinit();

    var scope = &block_scope.base;
    _ = &scope;

    var param_id: c_uint = 0;
    for (proto_payload.data.params, fn_ty.data.func.params) |*param, param_info| {
        const param_name = param.name orelse {
            proto_payload.data.is_extern = true;
            proto_payload.data.is_export = false;
            proto_payload.data.is_inline = false;
            try t.warn(&t.global_scope.base, fn_decl_loc, "function {s} parameter has no name, demoted to extern", .{fn_name});
            return t.addTopLevelDecl(fn_name, proto_node);
        };

        const is_const = param_info.ty.qual.@"const";

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

fn transVarDecl(t: *Translator, node: NodeIndex) Error!void {
    const decl = t.nodeData(node).decl;
    const name = t.tree.tokSlice(decl.name);
    return t.failDecl(decl.name, name, "unable to translate variable declaration", .{});
}

fn transEnumDecl(t: *Translator, scope: *Scope, enum_decl: *const Type.Enum, field_nodes: []const NodeIndex, source_loc: ?TokenIndex) Error!void {
    if (t.decl_table.get(@intFromPtr(enum_decl))) |_|
        return; // Avoid processing this decl twice
    const toplevel = scope.id == .root;
    const bs: *Scope.Block = if (!toplevel) try scope.findBlockScope(t) else undefined;

    var bare_name = t.mapper.lookup(enum_decl.name);
    const is_unnamed = bare_name[0] == '(';
    var name = bare_name;
    if (t.unnamed_typedefs.get(@intFromPtr(enum_decl))) |typedef_name| {
        bare_name = typedef_name;
        name = typedef_name;
    } else {
        if (is_unnamed) {
            bare_name = try std.fmt.allocPrint(t.arena, "unnamed_{d}", .{t.getMangle()});
        }
        name = try std.fmt.allocPrint(t.arena, "enum_{s}", .{bare_name});
    }
    if (!toplevel) name = try bs.makeMangledName(name);
    try t.decl_table.putNoClobber(t.gpa, @intFromPtr(enum_decl), name);

    const enum_type_node = if (!enum_decl.isIncomplete()) blk: {
        for (enum_decl.fields, field_nodes) |field, field_node| {
            var enum_val_name = t.mapper.lookup(field.name);
            if (!toplevel) {
                enum_val_name = try bs.makeMangledName(enum_val_name);
            }

            const enum_const_type_node: ?ZigNode = t.transType(scope, field.ty, .standard, field.name_tok) catch |err| switch (err) {
                error.UnsupportedType => null,
                else => |e| return e,
            };

            const val = t.tree.value_map.get(field_node).?;
            const enum_const_def = try ZigTag.enum_constant.create(t.arena, .{
                .name = enum_val_name,
                .is_public = toplevel,
                .type = enum_const_type_node,
                .value = try t.transCreateNodeInt(val),
            });
            if (toplevel)
                try t.addTopLevelDecl(enum_val_name, enum_const_def)
            else {
                try scope.appendNode(enum_const_def);
                try bs.discardVariable(enum_val_name);
            }
        }

        break :blk t.transType(scope, enum_decl.tag_ty, .standard, source_loc orelse 0) catch |err| switch (err) {
            error.UnsupportedType => {
                return t.failDecl(source_loc orelse 0, name, "unable to translate enum integer type", .{});
            },
            else => |e| return e,
        };
    } else blk: {
        try t.opaque_demotes.put(t.gpa, @intFromPtr(enum_decl), {});
        break :blk ZigTag.opaque_literal.init();
    };

    const is_pub = toplevel and !is_unnamed;
    const payload = try t.arena.create(ast.Payload.SimpleVarDecl);
    payload.* = .{
        .base = .{ .tag = ([2]ZigTag{ .var_simple, .pub_var_simple })[@intFromBool(is_pub)] },
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
        if (node.tag() != .pub_var_simple) {
            try bs.discardVariable(name);
        }
    }
}

fn transStaticAssert(t: *Translator, scope: *Scope, static_assert_node: NodeIndex) Error!void {
    const node_data = t.nodeData(static_assert_node).bin;

    const condition = t.transExpr(scope, node_data.lhs, .used) catch |err| switch (err) {
        error.UnsupportedTranslation, error.UnsupportedType => {
            return try t.warn(&t.global_scope.base, t.nodeLoc(node_data.lhs), "unable to translate _Static_assert condition", .{});
        },
        error.OutOfMemory => |e| return e,
    };

    // generate @compileError message that matches C compiler output
    const diagnostic = if (node_data.rhs != .none) str: {
        // Aro guarantees this to be a string literal.
        const str_val = t.tree.value_map.get(node_data.rhs).?;
        const str_ty = t.nodeType(node_data.rhs);

        const bytes = t.comp.interner.get(str_val.ref()).bytes;
        var buf = std.ArrayList(u8).init(t.gpa);
        defer buf.deinit();

        try buf.appendSlice("\"static assertion failed \\");

        try buf.ensureUnusedCapacity(bytes.len);
        try aro.Value.printString(bytes, str_ty, t.comp, buf.writer());
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

fn getTypeStr(t: *Translator, ty: Type) ![]const u8 {
    var buf: std.ArrayListUnmanaged(u8) = .empty;
    defer buf.deinit(t.gpa);
    const w = buf.writer(t.gpa);
    try ty.print(t.mapper, t.comp.langopts, w);
    return t.arena.dupe(u8, buf.items);
}

fn transType(t: *Translator, scope: *Scope, raw_ty: Type, qual_handling: Type.QualHandling, source_loc: TokenIndex) TypeError!ZigNode {
    const ty = raw_ty.canonicalize(qual_handling);
    if (ty.qual.atomic) {
        const type_name = try t.getTypeStr(ty);
        return t.fail(error.UnsupportedType, source_loc, "unsupported type: '{s}'", .{type_name});
    }

    switch (ty.specifier) {
        .void => return ZigTag.type.create(t.arena, "anyopaque"),
        .bool => return ZigTag.type.create(t.arena, "bool"),
        .char => return ZigTag.type.create(t.arena, "c_char"),
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
        .fp16, .float16 => return ZigTag.type.create(t.arena, "f16"),
        .float => return ZigTag.type.create(t.arena, "f32"),
        .double => return ZigTag.type.create(t.arena, "f64"),
        .long_double => return ZigTag.type.create(t.arena, "c_longdouble"),
        .float128 => return ZigTag.type.create(t.arena, "f128"),
        .@"enum" => {
            const enum_decl = ty.data.@"enum";
            var trans_scope = scope;
            if (enum_decl.name != .empty) {
                const decl_name = t.mapper.lookup(enum_decl.name);
                if (t.weak_global_names.contains(decl_name)) trans_scope = &t.global_scope.base;
            }
            try t.transEnumDecl(trans_scope, enum_decl, &.{}, source_loc);
            return ZigTag.identifier.create(t.arena, t.decl_table.get(@intFromPtr(enum_decl)).?);
        },
        .pointer => {
            const child_type = ty.elemType();

            const is_fn_proto = child_type.isFunc();
            const is_const = is_fn_proto or child_type.isConst();
            const is_volatile = child_type.qual.@"volatile";
            const elem_type = try t.transType(scope, child_type, qual_handling, source_loc);
            const ptr_info: @FieldType(ast.Payload.Pointer, "data") = .{
                .is_const = is_const,
                .is_volatile = is_volatile,
                .elem_type = elem_type,
            };
            if (is_fn_proto or
                t.typeIsOpaque(child_type) or
                t.typeWasDemotedToOpaque(child_type))
            {
                const ptr = try ZigTag.single_pointer.create(t.arena, ptr_info);
                return ZigTag.optional_type.create(t.arena, ptr);
            }

            return ZigTag.c_pointer.create(t.arena, ptr_info);
        },
        .unspecified_variable_len_array, .incomplete_array => {
            const child_type = ty.elemType();
            const is_const = child_type.qual.@"const";
            const is_volatile = child_type.qual.@"volatile";
            const elem_type = try t.transType(scope, child_type, qual_handling, source_loc);

            return ZigTag.c_pointer.create(t.arena, .{ .is_const = is_const, .is_volatile = is_volatile, .elem_type = elem_type });
        },
        .array,
        .static_array,
        => {
            const size = ty.arrayLen().?;
            const elem_type = try t.transType(scope, ty.elemType(), qual_handling, source_loc);
            return ZigTag.array_type.create(t.arena, .{ .len = size, .elem_type = elem_type });
        },
        .func,
        .var_args_func,
        .old_style_func,
        => return t.transFnType(scope, ty, ty, source_loc, .{}),
        .@"struct",
        .@"union",
        => {
            var trans_scope = scope;
            if (ty.isAnonymousRecord(t.comp)) {
                const record_decl = ty.data.record;
                const name_id = t.mapper.lookup(record_decl.name);
                if (t.weak_global_names.contains(name_id)) trans_scope = &t.global_scope.base;
            }
            try t.transRecordDecl(trans_scope, ty);
            const name = t.decl_table.get(@intFromPtr(ty.data.record)).?;
            return ZigTag.identifier.create(t.arena, name);
        },
        .attributed,
        .typeof_type,
        .typeof_expr,
        => unreachable,
        else => return error.UnsupportedType,
    }
}

/// Look ahead through the fields of the record to determine what the alignment of the record
/// would be without any align/packed/etc. attributes. This helps us determine whether or not
/// the fields with 0 offset need an `align` qualifier. Strictly speaking, we could just
/// pedantically assign those fields the same alignment as the parent's pointer alignment,
/// but this helps the generated code to be a little less verbose.
fn headFieldAlignment(record_decl: *const Type.Record) ?c_uint {
    const bits_per_byte = 8;
    const parent_ptr_alignment_bits = record_decl.type_layout.pointer_alignment_bits;
    const parent_ptr_alignment = parent_ptr_alignment_bits / bits_per_byte;
    var max_field_alignment_bits: u64 = 0;
    for (record_decl.fields) |field| {
        if (field.ty.getRecord()) |field_record_decl| {
            const child_record_alignment = field_record_decl.type_layout.field_alignment_bits;
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
    record_decl: *const Type.Record,
    head_field_alignment: ?c_uint,
    field_index: usize,
) ?c_uint {
    const fields = record_decl.fields;
    assert(fields.len != 0);
    const field = fields[field_index];

    const bits_per_byte = 8;
    const parent_ptr_alignment_bits = record_decl.type_layout.pointer_alignment_bits;
    const parent_ptr_alignment = parent_ptr_alignment_bits / bits_per_byte;

    // bitfields aren't supported yet. Until support is added, records with bitfields
    // should be demoted to opaque, and this function shouldn't be called for them.
    if (!field.isRegularField()) {
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
    const field_natural_alignment_bits: u64 = if (field.ty.getRecord()) |record| record.type_layout.field_alignment_bits else field_size_bits;
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
    is_inline: bool = false,
    fn_name: ?[]const u8 = null,
};

fn transFnType(
    t: *Translator,
    scope: *Scope,
    raw_ty: Type,
    fn_ty: Type,
    source_loc: TokenIndex,
    ctx: FnProtoContext,
) !ZigNode {
    const param_count: usize = fn_ty.data.func.params.len;
    const fn_params = try t.arena.alloc(ast.Payload.Param, param_count);

    for (fn_ty.data.func.params, fn_params) |param_info, *param_node| {
        const param_ty = param_info.ty;
        const is_noalias = param_ty.qual.restrict;

        const param_name: ?[]const u8 = if (param_info.name == .empty)
            null
        else
            t.mapper.lookup(param_info.name);

        const type_node = try t.transType(scope, param_ty, .standard, param_info.name_tok);
        param_node.* = .{
            .is_noalias = is_noalias,
            .name = param_name,
            .type = type_node,
        };
    }

    const linksection_string = blk: {
        if (raw_ty.getAttribute(.section)) |section| {
            break :blk t.comp.interner.get(section.name.ref()).bytes;
        }
        break :blk null;
    };

    const alignment: ?c_uint = raw_ty.requestedAlignment(t.comp) orelse null;

    const explicit_callconv = null;
    // const explicit_callconv = if ((ctx.is_inline or ctx.is_export or ctx.is_extern) and ctx.cc == .C) null else ctx.cc;

    const return_type_node = blk: {
        if (raw_ty.getAttribute(.noreturn) != null) {
            break :blk ZigTag.noreturn_type.init();
        } else {
            const return_ty = fn_ty.data.func.return_type;
            if (return_ty.is(.void)) {
                // convert primitive anyopaque to actual void (only for return type)
                break :blk ZigTag.void_type.init();
            } else {
                break :blk t.transType(scope, return_ty, .standard, source_loc) catch |err| switch (err) {
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
            .is_inline = ctx.is_inline,
            .is_var_args = switch (fn_ty.specifier) {
                .func => false,
                .var_args_func => true,
                .old_style_func => !ctx.is_export and !ctx.is_inline,
                else => unreachable,
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
fn transTypeIntWidthOf(t: *Translator, ty: Type, is_signed: bool) TypeError!ZigNode {
    return ZigTag.type.create(t.arena, switch (ty.specifier) {
        .char, .schar, .uchar => if (is_signed) "i8" else "u8",
        .short, .ushort => if (is_signed) "c_short" else "c_ushort",
        .int, .uint => if (is_signed) "c_int" else "c_uint",
        .long, .ulong => if (is_signed) "c_long" else "c_ulong",
        .long_long, .ulong_long => if (is_signed) "c_longlong" else "c_ulonglong",
        .int128, .uint128 => if (is_signed) "i128" else "u128",

        .bit_int => try std.fmt.allocPrint(t.arena, "{s}{d}", .{
            if (is_signed) "i" else "u",
            ty.data.int.bits,
        }),
        else => unreachable, // only call this function when it has already been determined the type is int
    });
}

// ============
// Type helpers
// ============

fn recordHasBitfield(record: *const Type.Record) bool {
    if (record.isIncomplete()) return false;
    for (record.fields) |field| {
        if (!field.isRegularField()) return true;
    }
    return false;
}

fn typeIsOpaque(t: *Translator, ty: Type) bool {
    return switch (ty.specifier) {
        .void => true,
        .@"struct", .@"union" => recordHasBitfield(ty.getRecord().?),
        .typeof_type => t.typeIsOpaque(ty.data.sub_type.*),
        .typeof_expr => t.typeIsOpaque(ty.data.expr.ty),
        .attributed => t.typeIsOpaque(ty.data.attributed.base),
        else => false,
    };
}

fn typeWasDemotedToOpaque(t: *Translator, ty: Type) bool {
    switch (ty.specifier) {
        .@"struct", .@"union" => {
            const record = ty.getRecord().?;
            if (t.opaque_demotes.contains(@intFromPtr(record))) return true;
            for (record.fields) |field| {
                if (t.typeWasDemotedToOpaque(field.ty)) return true;
            }
            return false;
        },

        .@"enum" => return t.opaque_demotes.contains(@intFromPtr(ty.data.@"enum")),

        .typeof_type => return t.typeWasDemotedToOpaque(ty.data.sub_type.*),
        .typeof_expr => return t.typeWasDemotedToOpaque(ty.data.expr.ty),
        .attributed => return t.typeWasDemotedToOpaque(ty.data.attributed.base),
        else => return false,
    }
}

/// Check if an expression is ultimately a reference to a function declaration
/// (which means it should not be unwrapped with `.?` in translated code)
fn isFunctionDeclRef(t: *Translator, base_node: NodeIndex) bool {
    const node_tags = t.tree.nodes.items(.tag);
    const node_data = t.tree.nodes.items(.data);
    var node = base_node;
    while (true) switch (node_tags[@intFromEnum(node)]) {
        .paren_expr => {
            node = node_data[@intFromEnum(node)].un;
        },
        .decl_ref_expr => {
            const res_ty = t.nodeType(node);
            return res_ty.isFunc();
        },
        .implicit_cast => {
            const cast = node_data[@intFromEnum(node)].cast;
            if (cast.kind == .function_to_pointer) {
                node = cast.operand;
                continue;
            }
            return false;
        },
        .addr_of_expr, .deref_expr => {
            node = node_data[@intFromEnum(node)].un;
        },
        .generic_expr, .generic_expr_one => {
            const child_nodes = t.tree.childNodes(node);
            const chosen = child_nodes[1];
            node = chosen;
        },
        else => return false,
    };
}
fn typeHasWrappingOverflow(t: *Translator, ty: Type) bool {
    if (ty.isUnsignedInt(t.comp)) {
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

fn transStmt(t: *Translator, scope: *Scope, stmt: NodeIndex) TransError!ZigNode {
    switch (t.nodeTag(stmt)) {
        .compound_stmt, .compound_stmt_two => {
            return t.transCompoundStmt(scope, stmt);
        },
        .static_assert => {
            try t.transStaticAssert(scope, stmt);
            return ZigTag.declaration.init();
        },
        .return_stmt => return t.transReturnStmt(scope, stmt),
        .null_stmt => return ZigTag.empty_block.init(),
        else => |tag| return t.fail(error.UnsupportedTranslation, t.nodeLoc(stmt), "TODO implement translation of stmt {s}", .{@tagName(tag)}),
    }
}

fn transCompoundStmtInline(t: *Translator, compound: NodeIndex, block: *Scope.Block) TransError!void {
    const stmts = t.tree.childNodes(compound);
    for (stmts) |stmt| {
        const result = try t.transStmt(&block.base, stmt);
        switch (result.tag()) {
            .declaration, .empty_block => {},
            else => try block.statements.append(t.gpa, result),
        }
    }
}

fn transCompoundStmt(t: *Translator, scope: *Scope, compound: NodeIndex) TransError!ZigNode {
    var block_scope = try Scope.Block.init(t, scope, false);
    defer block_scope.deinit();
    try t.transCompoundStmtInline(compound, &block_scope);
    return try block_scope.complete();
}

fn transReturnStmt(t: *Translator, scope: *Scope, return_stmt: NodeIndex) TransError!ZigNode {
    const operand = t.nodeData(return_stmt).un;
    if (operand == .none) return ZigTag.return_void.init();

    var rhs = try t.transExprCoercing(scope, operand);
    const return_ty = scope.findBlockReturnType();
    if (rhs.isBoolRes() and !return_ty.is(.bool)) {
        rhs = try ZigTag.int_from_bool.create(t.arena, rhs);
    }
    return ZigTag.@"return".create(t.arena, rhs);
}

// ======================
// Expression translation
// ======================

fn transExpr(t: *Translator, scope: *Scope, expr: NodeIndex, used: ResultUsed) TransError!ZigNode {
    std.debug.assert(expr != .none);
    const ty = t.nodeType(expr);
    if (t.tree.value_map.get(expr)) |val| {
        // TODO handle other values
        const int = try t.transCreateNodeInt(val);
        const as_node = try ZigTag.as.create(t.arena, .{
            .lhs = try t.transType(undefined, ty, .standard, undefined),
            .rhs = int,
        });
        return t.maybeSuppressResult(used, as_node);
    }
    return t.maybeSuppressResult(used, switch (t.nodeTag(expr)) {
        .paren_expr => {
            const operand = t.nodeData(expr).un;
            return t.transExpr(scope, operand, used);
        },
        .explicit_cast, .implicit_cast => return t.transCastExpr(scope, expr, used),
        .decl_ref_expr => try t.transDeclRefExpr(scope, expr),
        .addr_of_expr => res: {
            const operand = t.nodeData(expr).un;
            break :res try ZigTag.address_of.create(t.arena, try t.transExpr(scope, operand, .used));
        },
        .deref_expr => res: {
            if (t.typeWasDemotedToOpaque(ty))
                return fail(t, error.UnsupportedTranslation, t.nodeLoc(expr), "cannot dereference opaque type", .{});

            const operand = t.nodeData(expr).un;
            // Dereferencing a function pointer is a no-op.
            if (ty.isFunc()) return t.transExpr(scope, operand, used);

            break :res try ZigTag.deref.create(t.arena, try t.transExpr(scope, operand, .used));
        },
        .bool_not_expr => res: {
            const operand = t.nodeData(expr).un;
            break :res try ZigTag.not.create(t.arena, try t.transBoolExpr(scope, operand));
        },
        .bit_not_expr => res: {
            const operand = t.nodeData(expr).un;
            break :res try ZigTag.bit_not.create(t.arena, try t.transExpr(scope, operand, .used));
        },
        .negate_expr => res: {
            const operand = t.nodeData(expr).un;
            const operand_ty = t.nodeType(expr);
            if (!t.typeHasWrappingOverflow(operand_ty)) {
                const sub_expr_node = try t.transExpr(scope, operand, .used);
                const to_negate = if (sub_expr_node.isBoolRes()) blk: {
                    const ty_node = try ZigTag.type.create(t.arena, "c_int");
                    const int_node = try ZigTag.int_from_bool.create(t.arena, sub_expr_node);
                    break :blk try ZigTag.as.create(t.arena, .{ .lhs = ty_node, .rhs = int_node });
                } else sub_expr_node;

                break :res try ZigTag.negate.create(t.arena, to_negate);
            } else if (operand_ty.isUnsignedInt(t.comp)) {
                // use -% x for unsigned integers
                break :res try ZigTag.negate_wrap.create(t.arena, try t.transExpr(scope, operand, .used));
            } else return fail(t, error.UnsupportedTranslation, t.nodeLoc(expr), "C negation with non float non integer", .{});
        },
        .div_expr => res: {
            if (ty.isUnsignedInt(t.comp)) {
                const bin = t.nodeData(expr).bin;

                // signed integer division uses @divTrunc
                const lhs = try t.transExpr(scope, bin.lhs, .used);
                const rhs = try t.transExpr(scope, bin.rhs, .used);
                break :res try ZigTag.div_trunc.create(t.arena, .{ .lhs = lhs, .rhs = rhs });
            }
            // unsigned/float division uses the operator
            break :res try t.transBinExpr(scope, expr, .div);
        },
        .mod_expr => res: {
            if (ty.isUnsignedInt(t.comp)) {
                const bin = t.nodeData(expr).bin;

                // signed integer remainder uses std.zig.c_translation.signedRemainder
                const lhs = try t.transExpr(scope, bin.lhs, .used);
                const rhs = try t.transExpr(scope, bin.rhs, .used);
                break :res try ZigTag.signed_remainder.create(t.arena, .{ .lhs = lhs, .rhs = rhs });
            }
            // unsigned/float division uses the operator
            break :res try t.transBinExpr(scope, expr, .mod);
        },
        .add_expr => res: {
            const bin = t.nodeData(expr).bin;

            // `ptr + idx` and `idx + ptr` -> ptr + @as(usize, @bitCast(@as(isize, @intCast(idx))))
            if (ty.isPtr() and (t.nodeType(bin.lhs).signedness(t.comp) == .signed or
                t.nodeType(bin.rhs).signedness(t.comp) == .signed))
            {
                break :res try t.transPointerArithmeticSignedOp(scope, expr);
            }

            if (ty.isUnsignedInt(t.comp)) {
                break :res try t.transBinExpr(scope, expr, .add_wrap);
            } else {
                break :res try t.transBinExpr(scope, expr, .add);
            }
        },
        .sub_expr => res: {
            const bin = t.nodeData(expr).bin;

            // `ptr - idx` -> ptr - @as(usize, @bitCast(@as(isize, @intCast(idx))))
            if (ty.isPtr() and (t.nodeType(bin.lhs).signedness(t.comp) == .signed or
                t.nodeType(bin.rhs).signedness(t.comp) == .signed))
            {
                break :res try t.transPointerArithmeticSignedOp(scope, expr);
            }

            if (t.nodeType(bin.lhs).isPtr() and t.nodeType(bin.rhs).isPtr()) {
                break :res try t.transPtrDiffExpr(scope, expr);
            } else if (ty.isUnsignedInt(t.comp)) {
                break :res try t.transBinExpr(scope, expr, .sub_wrap);
            } else {
                break :res try t.transBinExpr(scope, expr, .sub);
            }
        },
        .mul_expr => if (ty.isUnsignedInt(t.comp))
            try t.transBinExpr(scope, expr, .mul_wrap)
        else
            try t.transBinExpr(scope, expr, .mul),

        .less_than_expr => try t.transBinExpr(scope, expr, .less_than),
        .greater_than_expr => try t.transBinExpr(scope, expr, .greater_than),
        .less_than_equal_expr => try t.transBinExpr(scope, expr, .less_than_equal),
        .greater_than_equal_expr => try t.transBinExpr(scope, expr, .greater_than_equal),
        .equal_expr => try t.transBinExpr(scope, expr, .equal),
        .not_equal_expr => try t.transBinExpr(scope, expr, .not_equal),

        .bool_and_expr => try t.transBinExpr(scope, expr, .@"and"),
        .bool_or_expr => try t.transBinExpr(scope, expr, .@"or"),

        .bit_and_expr => try t.transBinExpr(scope, expr, .bit_and),
        .bit_or_expr => try t.transBinExpr(scope, expr, .bit_or),
        .bit_xor_expr => try t.transBinExpr(scope, expr, .bit_xor),

        .shl_expr => try t.transShiftExpr(scope, expr, .shl),
        .shr_expr => try t.transShiftExpr(scope, expr, .shr),

        .builtin_call_expr => return t.transBuiltinCall(scope, expr, used),
        .builtin_call_expr_one => return t.transBuiltinCall(scope, expr, used),
        else => unreachable, // Not an expression.
    });
}

/// Same as `transExpr` but with the knowledge that the operand will be type coerced, and therefore
/// an `@as` would be redundant. This is used to prevent redundant `@as` in integer literals.
fn transExprCoercing(t: *Translator, scope: *Scope, expr: NodeIndex) TransError!ZigNode {
    // TODO bypass casts
    return t.transExpr(scope, expr, .used);
}

fn transBoolExpr(t: *Translator, scope: *Scope, expr: NodeIndex) TransError!ZigNode {
    const expr_tag = t.nodeTag(expr);
    if (expr_tag == .int_literal) {
        const int_val = t.tree.value_map.get(expr).?;
        return if (int_val.isZero(t.comp))
            ZigTag.false_literal.init()
        else
            ZigTag.true_literal.init();
    }
    if (expr_tag == .implicit_cast) {
        const cast = t.nodeData(expr).cast;
        if (cast.kind == .bool_to_int) {
            return t.transExpr(scope, cast.operand, .used);
        }
    }

    const maybe_bool_res = try t.transExpr(scope, expr, .used);
    if (maybe_bool_res.isBoolRes()) {
        return maybe_bool_res;
    }

    const ty = t.nodeType(expr);
    return t.finishBoolExpr(ty, maybe_bool_res);
}

fn finishBoolExpr(t: *Translator, ty: Type, node: ZigNode) TransError!ZigNode {
    if (ty.is(.nullptr_t)) {
        // node == null, always true
        return ZigTag.equal.create(t.arena, .{ .lhs = node, .rhs = ZigTag.null_literal.init() });
    }
    if (ty.isPtr()) {
        if (node.tag() == .string_literal) {
            // @intFromPtr(node) != 0, always true
            const int_from_ptr = try ZigTag.int_from_ptr.create(t.arena, node);
            return ZigTag.not_equal.create(t.arena, .{ .lhs = int_from_ptr, .rhs = ZigTag.zero_literal.init() });
        }
        // node != null
        return ZigTag.not_equal.create(t.arena, .{ .lhs = node, .rhs = ZigTag.null_literal.init() });
    }
    if (ty.isScalar()) {
        // node != 0
        return ZigTag.not_equal.create(t.arena, .{ .lhs = node, .rhs = ZigTag.zero_literal.init() });
    }
    unreachable; // Unexpected bool expression type
}

fn transCastExpr(t: *Translator, scope: *Scope, cast_node: NodeIndex, used: ResultUsed) TransError!ZigNode {
    const cast = t.nodeData(cast_node).cast;
    switch (cast.kind) {
        .lval_to_rval, .no_op, .function_to_pointer => {
            const sub_expr_node = try t.transExpr(scope, cast.operand, .used);
            return t.maybeSuppressResult(used, sub_expr_node);
        },
        .to_void => {
            return t.transExpr(scope, cast.operand, used);
        },
        else => return t.fail(error.UnsupportedTranslation, t.nodeLoc(cast_node), "TODO translate {s} cast", .{@tagName(cast.kind)}),
    }
}

fn transDeclRefExpr(t: *Translator, scope: *Scope, decl_ref_node: NodeIndex) TransError!ZigNode {
    const decl_ref = t.nodeData(decl_ref_node).decl_ref;

    const name = t.tree.tokSlice(decl_ref);
    const mangled_name = scope.getAlias(name);
    // TODO
    // const decl_is_var = @as(*const clang.Decl, @ptrCast(value_decl)).getKind() == .Var;
    // const potential_local_extern = if (decl_is_var) ((@as(*const clang.VarDecl, @ptrCast(value_decl)).getStorageClass() == .Extern) and (scope.id != .root)) else false;
    const decl_is_var = false;
    const potential_local_extern = false;

    var confirmed_local_extern = false;
    var ref_expr = val: {
        if (t.isFunctionDeclRef(decl_ref_node)) {
            break :val try ZigTag.fn_identifier.create(t.arena, mangled_name);
        } else if (potential_local_extern) {
            if (scope.getLocalExternAlias(name)) |v| {
                confirmed_local_extern = true;
                break :val try ZigTag.identifier.create(t.arena, v);
            } else {
                break :val try ZigTag.identifier.create(t.arena, mangled_name);
            }
        } else {
            break :val try ZigTag.identifier.create(t.arena, mangled_name);
        }
    };

    if (decl_is_var) {
        // const var_decl: NodeIndex = .none; // TODO
        if (false) { //var_decl.isStaticLocal()) {
            ref_expr = try ZigTag.field_access.create(t.arena, .{
                .lhs = ref_expr,
                .field_name = Scope.Block.static_inner_name,
            });
        } else if (confirmed_local_extern) {
            ref_expr = try ZigTag.field_access.create(t.arena, .{
                .lhs = ref_expr,
                .field_name = name, // by necessity, name will always == mangled_name
            });
        }
    }
    scope.skipVariableDiscard(mangled_name);
    return ref_expr;
}

fn transBinExpr(t: *Translator, scope: *Scope, bin_node: NodeIndex, op_id: ZigTag) TransError!ZigNode {
    const bin = t.nodeData(bin_node).bin;

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

    return t.transCreateNodeInfixOp(op_id, lhs, rhs);
}

fn transShiftExpr(t: *Translator, scope: *Scope, bin_node: NodeIndex, op_id: ZigTag) !ZigNode {
    std.debug.assert(op_id == .shl or op_id == .shr);
    const bin = t.nodeData(bin_node).bin;

    // lhs >> @intCast(rh)
    const lhs = try t.transExpr(scope, bin.lhs, .used);

    const rhs = try t.transExprCoercing(scope, bin.rhs);
    const rhs_casted = try ZigTag.int_cast.create(t.arena, rhs);

    return t.transCreateNodeInfixOp(op_id, lhs, rhs_casted);
}

fn transPtrDiffExpr(t: *Translator, scope: *Scope, bin_node: NodeIndex) TransError!ZigNode {
    const bin = t.nodeData(bin_node).bin;

    const lhs_uncasted = try t.transExpr(scope, bin.lhs, .used);
    const rhs_uncasted = try t.transExpr(scope, bin.rhs, .used);

    const lhs = try ZigTag.int_from_ptr.create(t.arena, lhs_uncasted);
    const rhs = try ZigTag.int_from_ptr.create(t.arena, rhs_uncasted);

    const sub_res = try t.transCreateNodeInfixOp(.sub_wrap, lhs, rhs);

    // @divExact(@as(<platform-ptrdiff_t>, @bitCast(@intFromPtr(lhs)) -% @intFromPtr(rhs)), @sizeOf(<lhs target type>))
    const ptrdiff_type = try t.transTypeIntWidthOf(t.nodeType(bin_node), true);

    const bitcast = try ZigTag.as.create(t.arena, .{
        .lhs = ptrdiff_type,
        .rhs = try ZigTag.bit_cast.create(t.arena, sub_res),
    });

    // C standard requires that pointer subtraction operands are of the same type,
    // otherwise it is undefined behavior. So we can assume the left and right
    // sides are the same Type and arbitrarily choose left.
    const lhs_ty = try t.transType(scope, t.nodeType(bin.lhs), .standard, t.nodeLoc(bin.lhs));
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
fn transPointerArithmeticSignedOp(t: *Translator, scope: *Scope, bin_node: NodeIndex) TransError!ZigNode {
    const is_add = t.nodeTag(bin_node) == .add_expr;
    const bin = t.nodeData(bin_node).bin;
    const swap_operands = is_add and t.nodeType(bin.lhs).signedness(t.comp) == .signed;

    const swizzled_lhs = if (swap_operands) bin.rhs else bin.lhs;
    const swizzled_rhs = if (swap_operands) bin.lhs else bin.rhs;

    const lhs_node = try t.transExpr(scope, swizzled_lhs, .used);
    const rhs_node = try t.transExpr(scope, swizzled_rhs, .used);

    const bitcast_node = try t.usizeCastForWrappingPtrArithmetic(rhs_node);

    return t.transCreateNodeInfixOp(if (is_add) .add else .sub, lhs_node, bitcast_node);
}

fn transBuiltinCall(
    t: *Translator,
    scope: *Scope,
    call_node: NodeIndex,
    used: ResultUsed,
) TransError!ZigNode {
    // TODO would be nice to have a helper to extract the builtin name
    const builtin_name, const arg_nodes = switch (t.nodeTag(call_node)) {
        .builtin_call_expr => blk: {
            const range = t.nodeData(call_node).range;
            const name = t.tree.tokSlice(@intFromEnum(t.tree.data[range.start]));
            const arg_nodes = t.tree.data[range.start + 1 .. range.end];
            break :blk .{ name, arg_nodes };
        },
        .builtin_call_expr_one => blk: {
            const decl = t.nodeData(call_node).decl;
            const name = t.tree.tokSlice(decl.name);
            const ptr: [*]const NodeIndex = @ptrCast(&decl.node);
            const slice = ptr[0..1];
            const end = std.mem.indexOfScalar(NodeIndex, slice, .none) orelse 1;
            const arg_nodes = slice[0..end];
            break :blk .{ name, arg_nodes };
        },
        else => unreachable,
    };
    const builtin = builtins.map.get(builtin_name) orelse {
        const call_loc = 0; // TODO builtin call source location
        return t.fail(error.UnsupportedTranslation, call_loc, "TODO implement function '{s}' in std.zig.c_builtins", .{builtin_name});
    };

    if (builtin.tag) |tag| switch (tag) {
        .byte_swap, .ceil, .cos, .sin, .exp, .exp2, .exp10, .abs, .log, .log2, .log10, .round, .sqrt, .trunc, .floor => {
            assert(arg_nodes.len == 1);
            const ptr = try t.arena.create(ast.Payload.UnOp);
            ptr.* = .{
                .base = .{ .tag = tag },
                .data = try t.transExpr(scope, arg_nodes[0], .used),
            };
            return ZigNode.initPayload(&ptr.base);
        },
        .@"unreachable" => return ZigTag.@"unreachable".init(),
        else => unreachable,
    };

    // Overriding a builtin function is a hard error in C
    // so we do not need to worry about aliasing.
    const gop = try t.rendered_builtins.getOrPut(t.gpa, builtin_name);
    if (!gop.found_existing) {
        try t.render_buf.appendSlice(builtin.source);
    }

    const args = try t.arena.alloc(ZigNode, arg_nodes.len);
    for (arg_nodes, args) |arg_node, *arg| {
        arg.* = try t.transExpr(scope, arg_node, .used);
    }

    const res = try ZigTag.call.create(t.arena, .{
        .lhs = try ZigTag.fn_identifier.create(t.arena, builtin_name),
        .args = args,
    });
    if (t.nodeType(call_node).is(.void)) return res;
    return t.maybeSuppressResult(used, res);
}

// =====================
// Node creation helpers
// =====================

fn transCreateNodeInt(t: *Translator, int: aro.Value) !ZigNode {
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

fn transCreateNodeInfixOp(
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

const PatternList = struct {
    patterns: []Pattern,

    /// Templates must be function-like macros
    /// first element is macro source, second element is the name of the function
    /// in std.lib.zig.c_translation.Macros which implements it
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

        fn init(self: *Pattern, allocator: mem.Allocator, template: [2][]const u8) Error!void {
            const source = template[0];
            const impl = template[1];

            var tok_list = std.ArrayList(CToken).init(allocator);
            defer tok_list.deinit();
            try tokenizeMacro(source, &tok_list);
            const tokens = try allocator.dupe(CToken, tok_list.items);

            self.* = .{
                .tokens = tokens,
                .source = source,
                .impl = impl,
                .args_hash = .{},
            };
            const ms = MacroSlicer{ .source = source, .tokens = tokens };
            buildArgsHash(allocator, ms, &self.args_hash) catch |err| switch (err) {
                error.UnexpectedMacroToken => unreachable,
                else => |e| return e,
            };
        }

        fn deinit(self: *Pattern, allocator: mem.Allocator) void {
            self.args_hash.deinit(allocator);
            allocator.free(self.tokens);
        }

        /// This function assumes that `ms` has already been validated to contain a function-like
        /// macro, and that the parsed template macro in `self` also contains a function-like
        /// macro. Please review this logic carefully if changing that assumption. Two
        /// function-like macros are considered equivalent if and only if they contain the same
        /// list of tokens, modulo parameter names.
        fn isEquivalent(self: Pattern, ms: MacroSlicer, args_hash: ArgsPositionMap) bool {
            if (self.tokens.len != ms.tokens.len) return false;
            if (args_hash.count() != self.args_hash.count()) return false;

            var i: usize = 2;
            while (self.tokens[i].id != .r_paren) : (i += 1) {}

            const pattern_slicer = MacroSlicer{ .source = self.source, .tokens = self.tokens };
            while (i < self.tokens.len) : (i += 1) {
                const pattern_token = self.tokens[i];
                const macro_token = ms.tokens[i];
                if (pattern_token.id != macro_token.id) return false;

                const pattern_bytes = pattern_slicer.slice(pattern_token);
                const macro_bytes = ms.slice(macro_token);
                switch (pattern_token.id) {
                    .identifier, .extended_identifier => {
                        const pattern_arg_index = self.args_hash.get(pattern_bytes);
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
        return PatternList{ .patterns = patterns };
    }

    fn deinit(self: *PatternList, allocator: mem.Allocator) void {
        for (self.patterns) |*pattern| pattern.deinit(allocator);
        allocator.free(self.patterns);
    }

    fn match(self: PatternList, allocator: mem.Allocator, ms: MacroSlicer) Error!?Pattern {
        var args_hash: ArgsPositionMap = .{};
        defer args_hash.deinit(allocator);

        buildArgsHash(allocator, ms, &args_hash) catch |err| switch (err) {
            error.UnexpectedMacroToken => return null,
            else => |e| return e,
        };

        for (self.patterns) |pattern| if (pattern.isEquivalent(ms, args_hash)) return pattern;
        return null;
    }
};

const MacroSlicer = struct {
    source: []const u8,
    tokens: []const CToken,

    fn slice(self: MacroSlicer, token: CToken) []const u8 {
        return self.source[token.start..token.end];
    }
};

// Maps macro parameter names to token position, for determining if different
// identifiers refer to the same positional argument in different macros.
const ArgsPositionMap = std.StringArrayHashMapUnmanaged(usize);

const ResultUsed = enum {
    used,
    unused,
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

// Testing here instead of test/translate_c.zig allows us to also test that the
// mapped function exists in `std.zig.c_translation.Macros`
test "Macro matching" {
    const testing = std.testing;
    const helper = struct {
        const MacroFunctions = std.zig.c_translation.Macros;
        fn checkMacro(allocator: mem.Allocator, pattern_list: PatternList, source: []const u8, comptime expected_match: ?[]const u8) !void {
            var tok_list = std.ArrayList(CToken).init(allocator);
            defer tok_list.deinit();
            try tokenizeMacro(source, &tok_list);
            const macro_slicer: MacroSlicer = .{ .source = source, .tokens = tok_list.items };
            const matched = try pattern_list.match(allocator, macro_slicer);
            if (expected_match) |expected| {
                try testing.expectEqualStrings(expected, matched.?.impl);
                try testing.expect(@hasDecl(MacroFunctions, expected));
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
