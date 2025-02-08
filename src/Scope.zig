const std = @import("std");

const aro = @import("aro");

const ast = @import("ast.zig");
const Translator = @import("Translator.zig");

const Scope = @This();

pub const SymbolTable = std.StringArrayHashMapUnmanaged(ast.Node);
pub const AliasList = std.ArrayListUnmanaged(struct {
    alias: []const u8,
    name: []const u8,
});

id: Id,
parent: ?*Scope,

pub const Id = enum {
    block,
    root,
    condition,
    loop,
    do_loop,
};

/// Used for the scope of condition expressions, for example `if (cond)`.
/// The block is lazily initialized because it is only needed for rare
/// cases of comma operators being used.
pub const Condition = struct {
    base: Scope,
    block: ?Block = null,

    fn getBlockScope(cond: *Condition, t: *Translator) !*Block {
        if (cond.block) |*b| return b;
        cond.block = try Block.init(t, &cond.base, true);
        return &cond.block.?;
    }

    pub fn deinit(cond: *Condition) void {
        if (cond.block) |*b| b.deinit();
    }
};

/// Represents an in-progress Node.Block. This struct is stack-allocated.
/// When it is deinitialized, it produces an Node.Block which is allocated
/// into the main arena.
pub const Block = struct {
    base: Scope,
    translator: *Translator,
    statements: std.ArrayListUnmanaged(ast.Node),
    variables: AliasList,
    mangle_count: u32 = 0,
    label: ?[]const u8 = null,

    /// By default all variables are discarded, since we do not know in advance if they
    /// will be used. This maps the variable's name to the Discard payload, so that if
    /// the variable is subsequently referenced we can indicate that the discard should
    /// be skipped during the intermediate AST -> Zig AST render step.
    variable_discards: std.StringArrayHashMapUnmanaged(*ast.Payload.Discard),

    /// When the block corresponds to a function, keep track of the return type
    /// so that the return expression can be cast, if necessary
    return_type: ?aro.QualType = null,

    /// C static local variables are wrapped in a block-local struct. The struct
    /// is named after the (mangled) variable name, the Zig variable within the
    /// struct itself is given this name.
    pub const static_inner_name = "static";

    /// C extern variables declared within a block are wrapped in a block-local
    /// struct. The struct is named ExternLocal_[variable_name], the Zig variable
    /// within the struct itself is [variable_name] by necessity since it's an
    /// extern reference to an existing symbol.
    const extern_inner_prepend = "ExternLocal";

    pub fn init(t: *Translator, parent: *Scope, labeled: bool) !Block {
        var blk: Block = .{
            .base = .{
                .id = .block,
                .parent = parent,
            },
            .translator = t,
            .statements = .empty,
            .variables = .empty,
            .variable_discards = .empty,
        };
        if (labeled) {
            blk.label = try blk.makeMangledName("blk");
        }
        return blk;
    }

    pub fn deinit(block: *Block) void {
        block.statements.deinit(block.translator.gpa);
        block.variables.deinit(block.translator.gpa);
        block.variable_discards.deinit(block.translator.gpa);
        block.* = undefined;
    }

    pub fn complete(block: *Block) !ast.Node {
        const arena = block.translator.arena;
        if (block.base.parent.?.id == .do_loop) {
            // We reserve 1 extra statement if the parent is a do_loop. This is in case of
            // do while, we want to put `if (cond) break;` at the end.
            const alloc_len = block.statements.items.len + @intFromBool(block.base.parent.?.id == .do_loop);
            var stmts = try arena.alloc(ast.Node, alloc_len);
            stmts.len = block.statements.items.len;
            @memcpy(stmts[0..block.statements.items.len], block.statements.items);
            return ast.Node.Tag.block.create(arena, .{
                .label = block.label,
                .stmts = stmts,
            });
        }
        if (block.statements.items.len == 0) return ast.Node.Tag.empty_block.init();
        return ast.Node.Tag.block.create(arena, .{
            .label = block.label,
            .stmts = try arena.dupe(ast.Node, block.statements.items),
        });
    }

    /// Given the desired name, return a name that does not shadow anything from outer scopes.
    /// Inserts the returned name into the scope.
    /// The name will not be visible to callers of getAlias.
    pub fn reserveMangledName(block: *Block, name: []const u8) ![]const u8 {
        return block.createMangledName(name, true);
    }

    /// Same as reserveMangledName, but enables the alias immediately.
    pub fn makeMangledName(block: *Block, name: []const u8) ![]const u8 {
        return block.createMangledName(name, false);
    }

    fn createMangledName(block: *Block, name: []const u8, reservation: bool) ![]const u8 {
        const arena = block.translator.arena;
        const name_copy = try arena.dupe(u8, name);
        var proposed_name = name_copy;
        while (block.contains(proposed_name)) {
            block.mangle_count += 1;
            proposed_name = try std.fmt.allocPrint(arena, "{s}_{d}", .{ name, block.mangle_count });
        }
        const new_mangle = try block.variables.addOne(block.translator.gpa);
        if (reservation) {
            new_mangle.* = .{ .name = name_copy, .alias = name_copy };
        } else {
            new_mangle.* = .{ .name = name_copy, .alias = proposed_name };
        }
        return proposed_name;
    }

    fn getAlias(block: *Block, name: []const u8) []const u8 {
        for (block.variables.items) |p| {
            if (std.mem.eql(u8, p.name, name))
                return p.alias;
        }
        return block.base.parent.?.getAlias(name);
    }

    /// Finds the (potentially) mangled struct name for a locally scoped extern variable given the original declaration name.
    ///
    /// Block scoped extern declarations translate to:
    ///     const MangledStructName = struct {extern [qualifiers] original_extern_variable_name: [type]};
    /// This finds MangledStructName given original_extern_variable_name for referencing correctly in transDeclRefExpr()
    fn getLocalExternAlias(block: *Block, name: []const u8) ?[]const u8 {
        for (block.statements.items) |node| {
            if (node.tag() == .extern_local_var) {
                const parent_node = node.castTag(.extern_local_var).?;
                const init_node = parent_node.data.init.castTag(.var_decl).?;
                if (std.mem.eql(u8, init_node.data.name, name)) {
                    return parent_node.data.name;
                }
            }
        }
        return null;
    }

    fn localContains(block: *Block, name: []const u8) bool {
        for (block.variables.items) |p| {
            if (std.mem.eql(u8, p.alias, name))
                return true;
        }
        return false;
    }

    fn contains(block: *Block, name: []const u8) bool {
        if (block.localContains(name))
            return true;
        return block.base.parent.?.contains(name);
    }

    pub fn discardVariable(block: *Block, name: []const u8) Translator.Error!void {
        const gpa = block.translator.gpa;
        const arena = block.translator.arena;
        const name_node = try ast.Node.Tag.identifier.create(arena, name);
        const discard = try ast.Node.Tag.discard.create(arena, .{ .should_skip = false, .value = name_node });
        try block.statements.append(gpa, discard);
        try block.variable_discards.putNoClobber(gpa, name, discard.castTag(.discard).?);
    }
};

pub const Root = struct {
    base: Scope,
    translator: *Translator,
    sym_table: SymbolTable,
    blank_macros: std.StringArrayHashMapUnmanaged(void),
    nodes: std.ArrayListUnmanaged(ast.Node),

    pub fn init(t: *Translator) Root {
        return .{
            .base = .{
                .id = .root,
                .parent = null,
            },
            .translator = t,
            .sym_table = .empty,
            .blank_macros = .empty,
            .nodes = .empty,
        };
    }

    pub fn deinit(root: *Root) void {
        root.sym_table.deinit(root.translator.gpa);
        root.blank_macros.deinit(root.translator.gpa);
        root.nodes.deinit(root.translator.gpa);
    }

    /// Check if the global scope contains this name, without looking into the "future", e.g.
    /// ignore the preprocessed decl and macro names.
    fn containsNow(root: *Root, name: []const u8) bool {
        return root.sym_table.contains(name);
    }

    /// Check if the global scope contains the name, includes all decls that haven't been translated yet.
    fn contains(root: *Root, name: []const u8) bool {
        return root.containsNow(name) or root.translator.global_names.contains(name) or root.translator.weak_global_names.contains(name);
    }
};

pub fn findBlockScope(inner: *Scope, t: *Translator) !*Block {
    var scope = inner;
    while (true) {
        switch (scope.id) {
            .root => unreachable,
            .block => return @fieldParentPtr("base", scope),
            .condition => return @as(*Condition, @fieldParentPtr("base", scope)).getBlockScope(t),
            else => scope = scope.parent.?,
        }
    }
}

pub fn findBlockReturnType(inner: *Scope) aro.QualType {
    var scope = inner;
    while (true) {
        switch (scope.id) {
            .root => unreachable,
            .block => {
                const block: *Block = @fieldParentPtr("base", scope);
                if (block.return_type) |qt| return qt;
                scope = scope.parent.?;
            },
            else => scope = scope.parent.?,
        }
    }
}

pub fn getAlias(scope: *Scope, name: []const u8) []const u8 {
    return switch (scope.id) {
        .root => name,
        .block => @as(*Block, @fieldParentPtr("base", scope)).getAlias(name),
        .loop, .do_loop, .condition => scope.parent.?.getAlias(name),
    };
}

pub fn getLocalExternAlias(scope: *Scope, name: []const u8) ?[]const u8 {
    return switch (scope.id) {
        .root => null,
        .block => ret: {
            const block = @as(*Block, @fieldParentPtr("base", scope));
            break :ret block.getLocalExternAlias(name);
        },
        .loop, .do_loop, .condition => scope.parent.?.getLocalExternAlias(name),
    };
}

fn contains(scope: *Scope, name: []const u8) bool {
    return switch (scope.id) {
        .root => @as(*Root, @fieldParentPtr("base", scope)).contains(name),
        .block => @as(*Block, @fieldParentPtr("base", scope)).contains(name),
        .loop, .do_loop, .condition => scope.parent.?.contains(name),
    };
}

fn getBreakableScope(inner: *Scope) *Scope {
    var scope = inner;
    while (true) {
        switch (scope.id) {
            .root => unreachable,
            .loop, .do_loop => return scope,
            else => scope = scope.parent.?,
        }
    }
}

/// Appends a node to the first block scope if inside a function, or to the root tree if not.
pub fn appendNode(inner: *Scope, node: ast.Node) !void {
    var scope = inner;
    while (true) {
        switch (scope.id) {
            .root => {
                const root: *Root = @fieldParentPtr("base", scope);
                return root.nodes.append(root.translator.gpa, node);
            },
            .block => {
                const block: *Block = @fieldParentPtr("base", scope);
                return block.statements.append(block.translator.gpa, node);
            },
            else => scope = scope.parent.?,
        }
    }
}

pub fn skipVariableDiscard(inner: *Scope, name: []const u8) void {
    if (true) {
        // TODO: due to 'local variable is never mutated' errors, we can
        // only skip discards if a variable is used as an lvalue, which
        // we don't currently have detection for in translate-c.
        // Once #17584 is completed, perhaps we can do away with this
        // logic entirely, and instead rely on render to fixup code.
        return;
    }
    var scope = inner;
    while (true) {
        switch (scope.id) {
            .root => return,
            .block => {
                const block: *Block = @fieldParentPtr("base", scope);
                if (block.variable_discards.get(name)) |discard| {
                    discard.data.should_skip = true;
                    return;
                }
            },
            else => {},
        }
        scope = scope.parent.?;
    }
}
