const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Node = extern union {
    /// If the tag value is less than Tag.no_payload_count, then no pointer
    /// dereference is needed.
    tag_if_small_enough: usize,
    ptr_otherwise: *Payload,

    pub const Tag = enum {
        /// Declarations add themselves to the correct scopes and should not be emitted as this tag.
        declaration,
        null_literal,
        undefined_literal,
        /// opaque {}
        opaque_literal,
        true_literal,
        false_literal,
        empty_block,
        return_void,
        zero_literal,
        one_literal,
        @"unreachable",
        void_type,
        noreturn_type,
        @"anytype",
        @"continue",
        @"break",
        // After this, the tag requires a payload.

        integer_literal,
        float_literal,
        string_literal,
        char_literal,
        enum_literal,
        /// "string"[0..end]
        string_slice,
        identifier,
        @"if",
        /// if (!operand) break;
        if_not_break,
        @"while",
        /// while (true) operand
        while_true,
        @"switch",
        /// else => operand,
        switch_else,
        /// items => body,
        switch_prong,
        break_val,
        @"return",
        field_access,
        array_access,
        call,
        var_decl,
        /// const name = struct { init }
        wrapped_local,
        /// var name = init.*
        mut_str,
        func,
        warning,
        @"struct",
        @"union",
        @"opaque",
        @"comptime",
        @"defer",
        array_init,
        tuple,
        container_init,
        container_init_dot,
        /// _ = operand;
        discard,

        // a + b
        add,
        // a = b
        add_assign,
        // c = (a = b)
        add_wrap,
        add_wrap_assign,
        sub,
        sub_assign,
        sub_wrap,
        sub_wrap_assign,
        mul,
        mul_assign,
        mul_wrap,
        mul_wrap_assign,
        div,
        div_assign,
        shl,
        shl_assign,
        shr,
        shr_assign,
        mod,
        mod_assign,
        @"and",
        @"or",
        less_than,
        less_than_equal,
        greater_than,
        greater_than_equal,
        equal,
        not_equal,
        bit_and,
        bit_and_assign,
        bit_or,
        bit_or_assign,
        bit_xor,
        bit_xor_assign,
        array_cat,
        ellipsis3,
        assign,

        /// @intCast(operand)
        int_cast,
        /// @constCast(operand)
        const_cast,
        /// @volatileCast(operand)
        volatile_cast,
        /// @divTrunc(lhs, rhs)
        div_trunc,
        /// @intFromBool(operand)
        int_from_bool,
        /// @as(lhs, rhs)
        as,
        /// @truncate(operand)
        truncate,
        /// @bitCast(operand)
        bit_cast,
        /// @floatCast(operand)
        float_cast,
        /// @intFromFloat(operand)
        int_from_float,
        /// @floatFromInt(operand)
        float_from_int,
        /// @ptrFromInt(operand)
        ptr_from_int,
        /// @intFromPtr(operand)
        int_from_ptr,
        /// @alignCast(operand)
        align_cast,
        /// @ptrCast(operand)
        ptr_cast,
        /// @divExact(lhs, rhs)
        div_exact,
        /// @offsetOf(lhs, rhs)
        offset_of,
        /// @splat(operand)
        vector_zero_init,
        /// @shuffle(type, a, b, mask)
        shuffle,
        /// @extern(ty, .{ .name = n })
        builtin_extern,

        /// @byteSwap(operand)
        byte_swap,
        /// @ceil(operand)
        ceil,
        /// @cos(operand)
        cos,
        /// @sin(operand)
        sin,
        /// @exp(operand)
        exp,
        /// @exp2(operand)
        exp2,
        /// @exp10(operand)
        exp10,
        /// @abs(operand)
        abs,
        /// @log(operand)
        log,
        /// @log2(operand)
        log2,
        /// @log10(operand)
        log10,
        /// @round(operand)
        round,
        /// @sqrt(operand)
        sqrt,
        /// @trunc(operand)
        trunc,
        /// @floor(operand)
        floor,

        /// __helpers.<name>(argshelper_call)
        helper_call,
        /// __helpers.<name>
        helper_ref,

        asm_simple,

        negate,
        negate_wrap,
        bit_not,
        not,
        address_of,
        /// .?
        unwrap,
        /// .*
        deref,

        block,
        /// { operand }
        block_single,

        sizeof,
        alignof,
        typeof,
        typeinfo,
        type,

        optional_type,
        c_pointer,
        single_pointer,
        array_type,
        null_sentinel_array_type,

        /// @Vector(lhs, rhs)
        vector,
        /// @import("std").mem.zeroes(operand)
        std_mem_zeroes,
        /// @import("std").mem.zeroInit(lhs, rhs)
        std_mem_zeroinit,
        // pub const name = @compileError(msg);
        fail_decl,
        // var actual = mangled;
        arg_redecl,
        /// pub const alias = actual;
        alias,
        /// const name = init;
        var_simple,
        /// pub const name = init;
        pub_var_simple,
        /// pub? const name (: type)? = value
        enum_constant,

        /// pub inline fn name(params) return_type body
        pub_inline_fn,

        /// array_type{}
        empty_array,
        /// [1]type{val} ** count
        array_filler,

        /// comptime { if (!(lhs)) @compileError(rhs); }
        static_assert,

        pub const last_no_payload_tag = Tag.@"break";
        pub const no_payload_count = @intFromEnum(last_no_payload_tag) + 1;

        pub fn Type(comptime t: Tag) type {
            return switch (t) {
                .declaration,
                .null_literal,
                .undefined_literal,
                .opaque_literal,
                .true_literal,
                .false_literal,
                .empty_block,
                .return_void,
                .zero_literal,
                .one_literal,
                .void_type,
                .noreturn_type,
                .@"anytype",
                .@"continue",
                .@"break",
                .@"unreachable",
                => @compileError("Type Tag " ++ @tagName(t) ++ " has no payload"),

                .std_mem_zeroes,
                .@"return",
                .@"comptime",
                .@"defer",
                .asm_simple,
                .negate,
                .negate_wrap,
                .bit_not,
                .not,
                .optional_type,
                .address_of,
                .unwrap,
                .deref,
                .int_from_ptr,
                .empty_array,
                .while_true,
                .if_not_break,
                .switch_else,
                .block_single,
                .int_from_bool,
                .sizeof,
                .alignof,
                .typeof,
                .typeinfo,
                .align_cast,
                .truncate,
                .bit_cast,
                .float_cast,
                .int_from_float,
                .float_from_int,
                .ptr_from_int,
                .ptr_cast,
                .int_cast,
                .const_cast,
                .volatile_cast,
                .vector_zero_init,
                .byte_swap,
                .ceil,
                .cos,
                .sin,
                .exp,
                .exp2,
                .exp10,
                .abs,
                .log,
                .log2,
                .log10,
                .round,
                .sqrt,
                .trunc,
                .floor,
                => Payload.UnOp,

                .add,
                .add_assign,
                .add_wrap,
                .add_wrap_assign,
                .sub,
                .sub_assign,
                .sub_wrap,
                .sub_wrap_assign,
                .mul,
                .mul_assign,
                .mul_wrap,
                .mul_wrap_assign,
                .div,
                .div_assign,
                .shl,
                .shl_assign,
                .shr,
                .shr_assign,
                .mod,
                .mod_assign,
                .@"and",
                .@"or",
                .less_than,
                .less_than_equal,
                .greater_than,
                .greater_than_equal,
                .equal,
                .not_equal,
                .bit_and,
                .bit_and_assign,
                .bit_or,
                .bit_or_assign,
                .bit_xor,
                .bit_xor_assign,
                .div_trunc,
                .as,
                .array_cat,
                .ellipsis3,
                .assign,
                .array_access,
                .std_mem_zeroinit,
                .vector,
                .div_exact,
                .offset_of,
                .static_assert,
                => Payload.BinOp,

                .integer_literal,
                .float_literal,
                .string_literal,
                .char_literal,
                .enum_literal,
                .identifier,
                .warning,
                .type,
                => Payload.Value,
                .discard => Payload.Discard,
                .@"if" => Payload.If,
                .@"while" => Payload.While,
                .@"switch", .array_init, .switch_prong => Payload.Switch,
                .break_val => Payload.BreakVal,
                .call => Payload.Call,
                .var_decl => Payload.VarDecl,
                .func => Payload.Func,
                .@"struct", .@"union", .@"opaque" => Payload.Container,
                .tuple => Payload.TupleInit,
                .container_init => Payload.ContainerInit,
                .container_init_dot => Payload.ContainerInitDot,
                .block => Payload.Block,
                .c_pointer, .single_pointer => Payload.Pointer,
                .array_type, .null_sentinel_array_type => Payload.Array,
                .arg_redecl, .alias, .fail_decl => Payload.ArgRedecl,
                .var_simple, .pub_var_simple, .wrapped_local, .mut_str => Payload.SimpleVarDecl,
                .enum_constant => Payload.EnumConstant,
                .array_filler => Payload.ArrayFiller,
                .pub_inline_fn => Payload.PubInlineFn,
                .field_access => Payload.FieldAccess,
                .string_slice => Payload.StringSlice,
                .shuffle => Payload.Shuffle,
                .builtin_extern => Payload.Extern,
                .helper_call => Payload.HelperCall,
                .helper_ref => Payload.HelperRef,
            };
        }

        pub fn init(comptime t: Tag) Node {
            comptime std.debug.assert(@intFromEnum(t) < Tag.no_payload_count);
            return .{ .tag_if_small_enough = @intFromEnum(t) };
        }

        pub fn create(comptime t: Tag, ally: Allocator, data: Data(t)) error{OutOfMemory}!Node {
            const ptr = try ally.create(t.Type());
            ptr.* = .{
                .base = .{ .tag = t },
                .data = data,
            };
            return Node{ .ptr_otherwise = &ptr.base };
        }

        pub fn Data(comptime t: Tag) type {
            return std.meta.fieldInfo(t.Type(), .data).type;
        }
    };

    pub fn tag(self: Node) Tag {
        if (self.tag_if_small_enough < Tag.no_payload_count) {
            return @enumFromInt(@as(std.meta.Tag(Tag), @intCast(self.tag_if_small_enough)));
        } else {
            return self.ptr_otherwise.tag;
        }
    }

    pub fn castTag(self: Node, comptime t: Tag) ?*t.Type() {
        if (self.tag_if_small_enough < Tag.no_payload_count)
            return null;

        if (self.ptr_otherwise.tag == t)
            return @alignCast(@fieldParentPtr("base", self.ptr_otherwise));

        return null;
    }

    pub fn initPayload(payload: *Payload) Node {
        std.debug.assert(@intFromEnum(payload.tag) >= Tag.no_payload_count);
        return .{ .ptr_otherwise = payload };
    }

    pub fn isNoreturn(node: Node, break_counts: bool) bool {
        switch (node.tag()) {
            .block => {
                const block_node = node.castTag(.block).?;
                if (block_node.data.stmts.len == 0) return false;

                const last = block_node.data.stmts[block_node.data.stmts.len - 1];
                return last.isNoreturn(break_counts);
            },
            .@"switch" => {
                const switch_node = node.castTag(.@"switch").?;

                for (switch_node.data.cases) |case| {
                    const body = if (case.castTag(.switch_else)) |some|
                        some.data
                    else if (case.castTag(.switch_prong)) |some|
                        some.data.cond
                    else
                        unreachable;

                    if (!body.isNoreturn(break_counts)) return false;
                }
                return true;
            },
            .@"return", .return_void => return true,
            .@"break" => if (break_counts) return true,
            else => {},
        }
        return false;
    }

    pub fn isBoolRes(res: Node) bool {
        switch (res.tag()) {
            .@"or",
            .@"and",
            .equal,
            .not_equal,
            .less_than,
            .less_than_equal,
            .greater_than,
            .greater_than_equal,
            .not,
            .false_literal,
            .true_literal,
            => return true,
            else => return false,
        }
    }
};

pub const Payload = struct {
    tag: Node.Tag,

    pub const Value = struct {
        base: Payload,
        data: []const u8,
    };

    pub const UnOp = struct {
        base: Payload,
        data: Node,
    };

    pub const BinOp = struct {
        base: Payload,
        data: struct {
            lhs: Node,
            rhs: Node,
        },
    };

    pub const Discard = struct {
        base: Payload,
        data: struct {
            should_skip: bool,
            value: Node,
        },
    };

    pub const If = struct {
        base: Payload,
        data: struct {
            cond: Node,
            then: Node,
            @"else": ?Node,
        },
    };

    pub const While = struct {
        base: Payload,
        data: struct {
            cond: Node,
            body: Node,
            cont_expr: ?Node,
        },
    };

    pub const Switch = struct {
        base: Payload,
        data: struct {
            cond: Node,
            cases: []Node,
        },
    };

    pub const BreakVal = struct {
        base: Payload,
        data: struct {
            label: ?[]const u8,
            val: Node,
        },
    };

    pub const Call = struct {
        base: Payload,
        data: struct {
            lhs: Node,
            args: []Node,
        },
    };

    pub const VarDecl = struct {
        base: Payload,
        data: struct {
            is_pub: bool,
            is_const: bool,
            is_extern: bool,
            is_export: bool,
            is_threadlocal: bool,
            alignment: ?c_uint,
            linksection_string: ?[]const u8,
            name: []const u8,
            type: Node,
            init: ?Node,
        },
    };

    pub const Func = struct {
        base: Payload,
        data: struct {
            is_pub: bool,
            is_extern: bool,
            is_export: bool,
            is_inline: bool,
            is_var_args: bool,
            name: ?[]const u8,
            linksection_string: ?[]const u8,
            explicit_callconv: ?CallingConvention,
            params: []Param,
            return_type: Node,
            body: ?Node,
            alignment: ?c_uint,
        },

        pub const CallingConvention = enum {
            c,
            x86_64_sysv,
            x86_64_win,
            x86_stdcall,
            x86_fastcall,
            x86_thiscall,
            x86_vectorcall,
            x86_regcall,
            aarch64_vfabi,
            aarch64_sve_pcs,
            arm_aapcs,
            arm_aapcs_vfp,
            m68k_rtd,
            riscv_vector,
        };
    };

    pub const Param = struct {
        is_noalias: bool,
        name: ?[]const u8,
        type: Node,
    };

    pub const Container = struct {
        base: Payload,
        data: struct {
            layout: enum { @"packed", @"extern", none },
            fields: []Field,
            decls: []Node,
        },

        pub const Field = struct {
            name: []const u8,
            type: Node,
            alignment: ?c_uint,
            default_value: ?Node,
        };
    };

    pub const TupleInit = struct {
        base: Payload,
        data: []Node,
    };

    pub const ContainerInit = struct {
        base: Payload,
        data: struct {
            lhs: Node,
            inits: []Initializer,
        },

        pub const Initializer = struct {
            name: []const u8,
            value: Node,
        };
    };

    pub const ContainerInitDot = struct {
        base: Payload,
        data: []Initializer,

        pub const Initializer = struct {
            name: []const u8,
            value: Node,
        };
    };

    pub const Block = struct {
        base: Payload,
        data: struct {
            label: ?[]const u8,
            stmts: []Node,
        },
    };

    pub const Array = struct {
        base: Payload,
        data: ArrayTypeInfo,

        pub const ArrayTypeInfo = struct {
            elem_type: Node,
            len: u64,
        };
    };

    pub const Pointer = struct {
        base: Payload,
        data: struct {
            elem_type: Node,
            is_const: bool,
            is_volatile: bool,
            is_allowzero: bool,
        },
    };

    pub const ArgRedecl = struct {
        base: Payload,
        data: struct {
            actual: []const u8,
            mangled: []const u8,
        },
    };

    pub const SimpleVarDecl = struct {
        base: Payload,
        data: struct {
            name: []const u8,
            init: Node,
        },
    };

    pub const EnumConstant = struct {
        base: Payload,
        data: struct {
            name: []const u8,
            is_public: bool,
            type: ?Node,
            value: Node,
        },
    };

    pub const ArrayFiller = struct {
        base: Payload,
        data: struct {
            type: Node,
            filler: Node,
            count: u64,
        },
    };

    pub const PubInlineFn = struct {
        base: Payload,
        data: struct {
            name: []const u8,
            params: []Param,
            return_type: Node,
            body: Node,
        },
    };

    pub const FieldAccess = struct {
        base: Payload,
        data: struct {
            lhs: Node,
            field_name: []const u8,
        },
    };

    pub const StringSlice = struct {
        base: Payload,
        data: struct {
            string: Node,
            end: u64,
        },
    };

    pub const Shuffle = struct {
        base: Payload,
        data: struct {
            element_type: Node,
            a: Node,
            b: Node,
            mask_vector: Node,
        },
    };

    pub const Extern = struct {
        base: Payload,
        data: struct {
            type: Node,
            name: Node,
        },
    };

    pub const HelperCall = struct {
        base: Payload,
        data: struct {
            name: []const u8,
            args: []const Node,
        },
    };

    pub const HelperRef = struct {
        base: Payload,
        data: []const u8,
    };
};

/// Converts the nodes into a Zig Ast.
/// Caller must free the source slice.
pub fn render(gpa: Allocator, nodes: []const Node) !std.zig.Ast {
    var ctx: Context = .{
        .gpa = gpa,
        .buf = std.ArrayList(u8).init(gpa),
    };
    defer ctx.buf.deinit();
    defer ctx.nodes.deinit(gpa);
    defer ctx.extra_data.deinit(gpa);
    defer ctx.tokens.deinit(gpa);

    // Estimate that each top level node has 10 child nodes.
    const estimated_node_count = nodes.len * 10 + 1; // +1 for the .root node
    try ctx.nodes.ensureTotalCapacity(gpa, estimated_node_count);
    // Estimate that each each node has 2 tokens.
    const estimated_tokens_count = estimated_node_count * 2;
    try ctx.tokens.ensureTotalCapacity(gpa, estimated_tokens_count);
    // Estimate that each each token is 3 bytes long.
    const estimated_buf_len = estimated_tokens_count * 3;
    try ctx.buf.ensureTotalCapacity(estimated_buf_len);

    ctx.nodes.appendAssumeCapacity(.{
        .tag = .root,
        .main_token = 0,
        .data = undefined,
    });

    const root_members = blk: {
        var result = std.ArrayList(NodeIndex).init(gpa);
        defer result.deinit();

        for (nodes) |node| {
            const res = (try renderNodeOpt(&ctx, node)) orelse continue;
            try result.append(res);
        }
        break :blk try ctx.listToSpan(result.items);
    };

    ctx.nodes.items(.data)[0] = .{ .extra_range = .{
        .start = root_members.start,
        .end = root_members.end,
    } };

    try ctx.tokens.append(gpa, .{
        .tag = .eof,
        .start = @as(u32, @intCast(ctx.buf.items.len)),
    });

    return .{
        .source = try ctx.buf.toOwnedSliceSentinel(0),
        .tokens = ctx.tokens.toOwnedSlice(),
        .nodes = ctx.nodes.toOwnedSlice(),
        .extra_data = try ctx.extra_data.toOwnedSlice(gpa),
        .errors = &.{},
        .mode = .zig,
    };
}

const NodeIndex = std.zig.Ast.Node.Index;
const NodeSubRange = std.zig.Ast.Node.SubRange;
const TokenIndex = std.zig.Ast.TokenIndex;
const TokenTag = std.zig.Token.Tag;

const Context = struct {
    gpa: Allocator,
    buf: std.ArrayList(u8),
    nodes: std.zig.Ast.NodeList = .{},
    extra_data: std.ArrayListUnmanaged(u32) = .empty,
    tokens: std.zig.Ast.TokenList = .{},

    fn addTokenFmt(c: *Context, tag: TokenTag, comptime format: []const u8, args: anytype) Allocator.Error!TokenIndex {
        const start_index = c.buf.items.len;
        try c.buf.print(format ++ " ", args);

        try c.tokens.append(c.gpa, .{
            .tag = tag,
            .start = @intCast(start_index),
        });

        return @intCast(c.tokens.len - 1);
    }

    fn addToken(c: *Context, tag: TokenTag, bytes: []const u8) Allocator.Error!TokenIndex {
        return c.addTokenFmt(tag, "{s}", .{bytes});
    }

    fn addIdentifier(c: *Context, bytes: []const u8) Allocator.Error!TokenIndex {
        if (std.zig.primitives.isPrimitive(bytes))
            return c.addTokenFmt(.identifier, "@\"{s}\"", .{bytes});
        return c.addTokenFmt(.identifier, "{f}", .{std.zig.fmtId(bytes)});
    }

    fn listToSpan(c: *Context, list: []const NodeIndex) Allocator.Error!NodeSubRange {
        try c.extra_data.appendSlice(c.gpa, @ptrCast(list));
        return .{
            .start = @enumFromInt(c.extra_data.items.len - list.len),
            .end = @enumFromInt(c.extra_data.items.len),
        };
    }

    fn addNode(c: *Context, elem: std.zig.Ast.Node) Allocator.Error!NodeIndex {
        const result: NodeIndex = @enumFromInt(c.nodes.len);
        try c.nodes.append(c.gpa, elem);
        return result;
    }

    fn addExtra(c: *Context, extra: anytype) Allocator.Error!std.zig.Ast.ExtraIndex {
        const fields = std.meta.fields(@TypeOf(extra));
        try c.extra_data.ensureUnusedCapacity(c.gpa, fields.len);
        const result: std.zig.Ast.ExtraIndex = @enumFromInt(c.extra_data.items.len);
        inline for (fields) |field| {
            const data: u32 = switch (field.type) {
                NodeIndex,
                std.zig.Ast.Node.OptionalIndex,
                std.zig.Ast.OptionalTokenIndex,
                std.zig.Ast.ExtraIndex,
                => @intFromEnum(@field(extra, field.name)),
                TokenIndex,
                => @field(extra, field.name),
                else => @compileError("unexpected field type"),
            };
            c.extra_data.appendAssumeCapacity(data);
        }
        return result;
    }
};

fn renderNodeOpt(c: *Context, node: Node) Allocator.Error!?NodeIndex {
    switch (node.tag()) {
        .warning => {
            const payload = node.castTag(.warning).?.data;
            try c.buf.appendSlice(payload);
            try c.buf.append('\n');
            return null;
        },
        .discard => {
            const payload = node.castTag(.discard).?.data;
            if (payload.should_skip) return null;

            return try renderNode(c, node);
        },
        else => return try renderNode(c, node),
    }
}

fn renderNode(c: *Context, node: Node) Allocator.Error!NodeIndex {
    switch (node.tag()) {
        .declaration => unreachable,
        .warning => unreachable,
        .discard => {
            const payload = node.castTag(.discard).?.data;
            std.debug.assert(!payload.should_skip);

            const lhs = try c.addNode(.{
                .tag = .identifier,
                .main_token = try c.addToken(.identifier, "_"),
                .data = undefined,
            });
            const main_token = try c.addToken(.equal, "=");
            if (payload.value.tag() == .identifier) {
                // Render as `_ = &foo;` to avoid tripping "pointless discard" and "local variable never mutated" errors.
                var addr_of_pl: Payload.UnOp = .{
                    .base = .{ .tag = .address_of },
                    .data = payload.value,
                };
                const addr_of: Node = .{ .ptr_otherwise = &addr_of_pl.base };
                return try c.addNode(.{
                    .tag = .assign,
                    .main_token = main_token,
                    .data = .{ .node_and_node = .{
                        lhs, try renderNode(c, addr_of),
                    } },
                });
            } else {
                return try c.addNode(.{
                    .tag = .assign,
                    .main_token = main_token,
                    .data = .{ .node_and_node = .{
                        lhs, try renderNode(c, payload.value),
                    } },
                });
            }
        },
        .std_mem_zeroes => {
            const payload = node.castTag(.std_mem_zeroes).?.data;
            const import_node = try renderStdImport(c, &.{ "mem", "zeroes" });
            return renderCall(c, import_node, &.{payload});
        },
        .std_mem_zeroinit => {
            const payload = node.castTag(.std_mem_zeroinit).?.data;
            const import_node = try renderStdImport(c, &.{ "mem", "zeroInit" });
            return renderCall(c, import_node, &.{ payload.lhs, payload.rhs });
        },
        .vector => {
            const payload = node.castTag(.vector).?.data;
            return renderBuiltinCall(c, "@Vector", &.{ payload.lhs, payload.rhs });
        },
        .call => {
            const payload = node.castTag(.call).?.data;
            const lhs = try renderNodeGrouped(c, payload.lhs);
            return renderCall(c, lhs, payload.args);
        },
        .null_literal => return c.addNode(.{
            .tag = .identifier,
            .main_token = try c.addToken(.identifier, "null"),
            .data = undefined,
        }),
        .undefined_literal => return c.addNode(.{
            .tag = .identifier,
            .main_token = try c.addToken(.identifier, "undefined"),
            .data = undefined,
        }),
        .true_literal => return c.addNode(.{
            .tag = .identifier,
            .main_token = try c.addToken(.identifier, "true"),
            .data = undefined,
        }),
        .false_literal => return c.addNode(.{
            .tag = .identifier,
            .main_token = try c.addToken(.identifier, "false"),
            .data = undefined,
        }),
        .zero_literal => return c.addNode(.{
            .tag = .number_literal,
            .main_token = try c.addToken(.number_literal, "0"),
            .data = undefined,
        }),
        .one_literal => return c.addNode(.{
            .tag = .number_literal,
            .main_token = try c.addToken(.number_literal, "1"),
            .data = undefined,
        }),
        .@"unreachable" => return c.addNode(.{
            .tag = .unreachable_literal,
            .main_token = try c.addToken(.keyword_unreachable, "unreachable"),
            .data = undefined,
        }),
        .void_type => return c.addNode(.{
            .tag = .identifier,
            .main_token = try c.addToken(.identifier, "void"),
            .data = undefined,
        }),
        .noreturn_type => return c.addNode(.{
            .tag = .identifier,
            .main_token = try c.addToken(.identifier, "noreturn"),
            .data = undefined,
        }),
        .@"continue" => return c.addNode(.{
            .tag = .@"continue",
            .main_token = try c.addToken(.keyword_continue, "continue"),
            .data = .{ .opt_token_and_opt_node = .{
                .none, .none,
            } },
        }),
        .return_void => return c.addNode(.{
            .tag = .@"return",
            .main_token = try c.addToken(.keyword_return, "return"),
            .data = .{ .opt_node = .none },
        }),
        .@"break" => return c.addNode(.{
            .tag = .@"break",
            .main_token = try c.addToken(.keyword_break, "break"),
            .data = .{ .opt_token_and_opt_node = .{
                .none, .none,
            } },
        }),
        .break_val => {
            const payload = node.castTag(.break_val).?.data;
            const tok = try c.addToken(.keyword_break, "break");
            const break_label = if (payload.label) |some| blk: {
                _ = try c.addToken(.colon, ":");
                break :blk try c.addIdentifier(some);
            } else 0;
            return c.addNode(.{
                .tag = .@"break",
                .main_token = tok,
                .data = .{ .opt_token_and_opt_node = .{
                    .fromToken(break_label), (try renderNode(c, payload.val)).toOptional(),
                } },
            });
        },
        .@"return" => {
            const payload = node.castTag(.@"return").?.data;
            return c.addNode(.{
                .tag = .@"return",
                .main_token = try c.addToken(.keyword_return, "return"),
                .data = .{ .opt_node = (try renderNode(c, payload)).toOptional() },
            });
        },
        .@"comptime" => {
            const payload = node.castTag(.@"comptime").?.data;
            return c.addNode(.{
                .tag = .@"comptime",
                .main_token = try c.addToken(.keyword_comptime, "comptime"),
                .data = .{
                    .node = try renderNode(c, payload),
                },
            });
        },
        .@"defer" => {
            const payload = node.castTag(.@"defer").?.data;
            return c.addNode(.{
                .tag = .@"defer",
                .main_token = try c.addToken(.keyword_defer, "defer"),
                .data = .{
                    .node = try renderNode(c, payload),
                },
            });
        },
        .asm_simple => {
            const payload = node.castTag(.asm_simple).?.data;
            const asm_token = try c.addToken(.keyword_asm, "asm");
            _ = try c.addToken(.l_paren, "(");
            return c.addNode(.{
                .tag = .asm_simple,
                .main_token = asm_token,
                .data = .{ .node_and_token = .{
                    try renderNode(c, payload),
                    try c.addToken(.r_paren, ")"),
                } },
            });
        },
        .type => {
            const payload = node.castTag(.type).?.data;
            return c.addNode(.{
                .tag = .identifier,
                .main_token = try c.addToken(.identifier, payload),
                .data = undefined,
            });
        },
        .identifier => {
            const payload = node.castTag(.identifier).?.data;
            return c.addNode(.{
                .tag = .identifier,
                .main_token = try c.addIdentifier(payload),
                .data = undefined,
            });
        },
        .float_literal => {
            const payload = node.castTag(.float_literal).?.data;
            return c.addNode(.{
                .tag = .number_literal,
                .main_token = try c.addToken(.number_literal, payload),
                .data = undefined,
            });
        },
        .integer_literal => {
            const payload = node.castTag(.integer_literal).?.data;
            return c.addNode(.{
                .tag = .number_literal,
                .main_token = try c.addToken(.number_literal, payload),
                .data = undefined,
            });
        },
        .string_literal => {
            const payload = node.castTag(.string_literal).?.data;
            return c.addNode(.{
                .tag = .string_literal,
                .main_token = try c.addToken(.string_literal, payload),
                .data = undefined,
            });
        },
        .char_literal => {
            const payload = node.castTag(.char_literal).?.data;
            return c.addNode(.{
                .tag = .char_literal,
                .main_token = try c.addToken(.char_literal, payload),
                .data = undefined,
            });
        },
        .enum_literal => {
            const payload = node.castTag(.enum_literal).?.data;
            _ = try c.addToken(.period, ".");
            return c.addNode(.{
                .tag = .enum_literal,
                .main_token = try c.addToken(.identifier, payload),
                .data = undefined,
            });
        },
        .string_slice => {
            const payload = node.castTag(.string_slice).?.data;

            const string = try renderNode(c, payload.string);
            const l_bracket = try c.addToken(.l_bracket, "[");
            const start = try c.addNode(.{
                .tag = .number_literal,
                .main_token = try c.addToken(.number_literal, "0"),
                .data = undefined,
            });
            _ = try c.addToken(.ellipsis2, "..");
            const end = try c.addNode(.{
                .tag = .number_literal,
                .main_token = try c.addTokenFmt(.number_literal, "{d}", .{payload.end}),
                .data = undefined,
            });
            _ = try c.addToken(.r_bracket, "]");

            return c.addNode(.{
                .tag = .slice,
                .main_token = l_bracket,
                .data = .{ .node_and_extra = .{
                    string, try c.addExtra(std.zig.Ast.Node.Slice{
                        .start = start,
                        .end = end,
                    }),
                } },
            });
        },
        .fail_decl => {
            const payload = node.castTag(.fail_decl).?.data;
            // pub const name = @compileError(msg);
            _ = try c.addToken(.keyword_pub, "pub");
            const const_tok = try c.addToken(.keyword_const, "const");
            _ = try c.addIdentifier(payload.actual);
            _ = try c.addToken(.equal, "=");

            const compile_error_tok = try c.addToken(.builtin, "@compileError");
            _ = try c.addToken(.l_paren, "(");
            const err_msg_tok = try c.addTokenFmt(.string_literal, "\"{f}\"", .{std.zig.fmtString(payload.mangled)});
            const err_msg = try c.addNode(.{
                .tag = .string_literal,
                .main_token = err_msg_tok,
                .data = undefined,
            });
            _ = try c.addToken(.r_paren, ")");
            const compile_error = try c.addNode(.{
                .tag = .builtin_call_two,
                .main_token = compile_error_tok,
                .data = .{ .opt_node_and_opt_node = .{
                    err_msg.toOptional(), .none,
                } },
            });
            _ = try c.addToken(.semicolon, ";");

            return c.addNode(.{
                .tag = .simple_var_decl,
                .main_token = const_tok,
                .data = .{
                    .opt_node_and_opt_node = .{
                        .none, // Type expression
                        compile_error.toOptional(), // Init expression
                    },
                },
            });
        },
        .pub_var_simple, .var_simple => {
            const payload = @as(*Payload.SimpleVarDecl, @alignCast(@fieldParentPtr("base", node.ptr_otherwise))).data;
            if (node.tag() == .pub_var_simple) _ = try c.addToken(.keyword_pub, "pub");
            const const_tok = try c.addToken(.keyword_const, "const");
            _ = try c.addIdentifier(payload.name);
            _ = try c.addToken(.equal, "=");

            const init = try renderNode(c, payload.init);
            _ = try c.addToken(.semicolon, ";");

            return c.addNode(.{
                .tag = .simple_var_decl,
                .main_token = const_tok,
                .data = .{
                    .opt_node_and_opt_node = .{
                        .none, // Type expression
                        init.toOptional(), // Init expression
                    },
                },
            });
        },
        .wrapped_local => {
            const payload = node.castTag(.wrapped_local).?.data;

            const const_tok = try c.addToken(.keyword_const, "const");
            _ = try c.addIdentifier(payload.name);
            _ = try c.addToken(.equal, "=");

            const kind_tok = try c.addToken(.keyword_struct, "struct");
            _ = try c.addToken(.l_brace, "{");

            const container_def = try c.addNode(.{
                .tag = .container_decl_two_trailing,
                .main_token = kind_tok,
                .data = .{ .opt_node_and_opt_node = .{
                    (try renderNode(c, payload.init)).toOptional(), .none,
                } },
            });
            _ = try c.addToken(.r_brace, "}");
            _ = try c.addToken(.semicolon, ";");

            return c.addNode(.{
                .tag = .simple_var_decl,
                .main_token = const_tok,
                .data = .{
                    .opt_node_and_opt_node = .{
                        .none, // Type expression
                        container_def.toOptional(), // Init expression
                    },
                },
            });
        },
        .mut_str => {
            const payload = node.castTag(.mut_str).?.data;

            const var_tok = try c.addToken(.keyword_var, "var");
            _ = try c.addIdentifier(payload.name);
            _ = try c.addToken(.equal, "=");

            const deref = try c.addNode(.{
                .tag = .deref,
                .data = .{
                    .node = try renderNodeGrouped(c, payload.init),
                },
                .main_token = try c.addToken(.period_asterisk, ".*"),
            });
            _ = try c.addToken(.semicolon, ";");

            return c.addNode(.{
                .tag = .simple_var_decl,
                .main_token = var_tok,
                .data = .{
                    .opt_node_and_opt_node = .{
                        .none, // Type expression
                        deref.toOptional(), // Init expression
                    },
                },
            });
        },
        .var_decl => return renderVar(c, node),
        .arg_redecl, .alias => {
            const payload = @as(*Payload.ArgRedecl, @alignCast(@fieldParentPtr("base", node.ptr_otherwise))).data;
            if (node.tag() == .alias) _ = try c.addToken(.keyword_pub, "pub");
            const mut_tok = if (node.tag() == .alias)
                try c.addToken(.keyword_const, "const")
            else
                try c.addToken(.keyword_var, "var");
            _ = try c.addIdentifier(payload.actual);
            _ = try c.addToken(.equal, "=");

            const init = try c.addNode(.{
                .tag = .identifier,
                .main_token = try c.addIdentifier(payload.mangled),
                .data = undefined,
            });
            _ = try c.addToken(.semicolon, ";");

            return c.addNode(.{
                .tag = .simple_var_decl,
                .main_token = mut_tok,
                .data = .{
                    .opt_node_and_opt_node = .{
                        .none, // Type expression
                        init.toOptional(), // Init expression
                    },
                },
            });
        },
        .int_cast => {
            const payload = node.castTag(.int_cast).?.data;
            return renderBuiltinCall(c, "@intCast", &.{payload});
        },
        .const_cast => {
            const payload = node.castTag(.const_cast).?.data;
            return renderBuiltinCall(c, "@constCast", &.{payload});
        },
        .volatile_cast => {
            const payload = node.castTag(.volatile_cast).?.data;
            return renderBuiltinCall(c, "@volatileCast", &.{payload});
        },
        .div_trunc => {
            const payload = node.castTag(.div_trunc).?.data;
            return renderBuiltinCall(c, "@divTrunc", &.{ payload.lhs, payload.rhs });
        },
        .int_from_bool => {
            const payload = node.castTag(.int_from_bool).?.data;
            return renderBuiltinCall(c, "@intFromBool", &.{payload});
        },
        .as => {
            const payload = node.castTag(.as).?.data;
            return renderBuiltinCall(c, "@as", &.{ payload.lhs, payload.rhs });
        },
        .truncate => {
            const payload = node.castTag(.truncate).?.data;
            return renderBuiltinCall(c, "@truncate", &.{payload});
        },
        .bit_cast => {
            const payload = node.castTag(.bit_cast).?.data;
            return renderBuiltinCall(c, "@bitCast", &.{payload});
        },
        .float_cast => {
            const payload = node.castTag(.float_cast).?.data;
            return renderBuiltinCall(c, "@floatCast", &.{payload});
        },
        .int_from_float => {
            const payload = node.castTag(.int_from_float).?.data;
            return renderBuiltinCall(c, "@intFromFloat", &.{payload});
        },
        .float_from_int => {
            const payload = node.castTag(.float_from_int).?.data;
            return renderBuiltinCall(c, "@floatFromInt", &.{payload});
        },
        .ptr_from_int => {
            const payload = node.castTag(.ptr_from_int).?.data;
            return renderBuiltinCall(c, "@ptrFromInt", &.{payload});
        },
        .int_from_ptr => {
            const payload = node.castTag(.int_from_ptr).?.data;
            return renderBuiltinCall(c, "@intFromPtr", &.{payload});
        },
        .align_cast => {
            const payload = node.castTag(.align_cast).?.data;
            return renderBuiltinCall(c, "@alignCast", &.{payload});
        },
        .ptr_cast => {
            const payload = node.castTag(.ptr_cast).?.data;
            return renderBuiltinCall(c, "@ptrCast", &.{payload});
        },
        .div_exact => {
            const payload = node.castTag(.div_exact).?.data;
            return renderBuiltinCall(c, "@divExact", &.{ payload.lhs, payload.rhs });
        },
        .offset_of => {
            const payload = node.castTag(.offset_of).?.data;
            return renderBuiltinCall(c, "@offsetOf", &.{ payload.lhs, payload.rhs });
        },
        .sizeof => {
            const payload = node.castTag(.sizeof).?.data;
            return renderBuiltinCall(c, "@sizeOf", &.{payload});
        },
        .shuffle => {
            const payload = node.castTag(.shuffle).?.data;
            return renderBuiltinCall(c, "@shuffle", &.{
                payload.element_type,
                payload.a,
                payload.b,
                payload.mask_vector,
            });
        },
        .builtin_extern => {
            const payload = node.castTag(.builtin_extern).?.data;

            var info_inits: [1]Payload.ContainerInitDot.Initializer = .{
                .{ .name = "name", .value = payload.name },
            };
            var info_payload: Payload.ContainerInitDot = .{
                .base = .{ .tag = .container_init_dot },
                .data = &info_inits,
            };

            return renderBuiltinCall(c, "@extern", &.{
                payload.type,
                .{ .ptr_otherwise = &info_payload.base },
            });
        },
        .helper_call => {
            const payload = node.castTag(.helper_call).?.data;
            const helpers_tok = try c.addNode(.{
                .tag = .identifier,
                .main_token = try c.addIdentifier("__helpers"),
                .data = undefined,
            });
            const func = try renderFieldAccess(c, helpers_tok, payload.name);
            return renderCall(c, func, payload.args);
        },
        .helper_ref => {
            const payload = node.castTag(.helper_ref).?.data;
            const helpers_tok = try c.addNode(.{
                .tag = .identifier,
                .main_token = try c.addIdentifier("__helpers"),
                .data = undefined,
            });
            return renderFieldAccess(c, helpers_tok, payload);
        },
        .alignof => {
            const payload = node.castTag(.alignof).?.data;
            return renderBuiltinCall(c, "@alignOf", &.{payload});
        },
        .typeof => {
            const payload = node.castTag(.typeof).?.data;
            return renderBuiltinCall(c, "@TypeOf", &.{payload});
        },
        .typeinfo => {
            const payload = node.castTag(.typeinfo).?.data;
            return renderBuiltinCall(c, "@typeInfo", &.{payload});
        },
        .byte_swap => {
            const payload = node.castTag(.byte_swap).?.data;
            return renderBuiltinCall(c, "@byteSwap", &.{payload});
        },
        .ceil => {
            const payload = node.castTag(.ceil).?.data;
            return renderBuiltinCall(c, "@ceil", &.{payload});
        },
        .cos => {
            const payload = node.castTag(.cos).?.data;
            return renderBuiltinCall(c, "@cos", &.{payload});
        },
        .sin => {
            const payload = node.castTag(.sin).?.data;
            return renderBuiltinCall(c, "@sin", &.{payload});
        },
        .exp => {
            const payload = node.castTag(.exp).?.data;
            return renderBuiltinCall(c, "@exp", &.{payload});
        },
        .exp2 => {
            const payload = node.castTag(.exp2).?.data;
            return renderBuiltinCall(c, "@exp2", &.{payload});
        },
        .exp10 => {
            const payload = node.castTag(.exp10).?.data;
            return renderBuiltinCall(c, "@exp10", &.{payload});
        },
        .abs => {
            const payload = node.castTag(.abs).?.data;
            return renderBuiltinCall(c, "@abs", &.{payload});
        },
        .log => {
            const payload = node.castTag(.log).?.data;
            return renderBuiltinCall(c, "@log", &.{payload});
        },
        .log2 => {
            const payload = node.castTag(.log2).?.data;
            return renderBuiltinCall(c, "@log2", &.{payload});
        },
        .log10 => {
            const payload = node.castTag(.log10).?.data;
            return renderBuiltinCall(c, "@log10", &.{payload});
        },
        .round => {
            const payload = node.castTag(.round).?.data;
            return renderBuiltinCall(c, "@round", &.{payload});
        },
        .sqrt => {
            const payload = node.castTag(.sqrt).?.data;
            return renderBuiltinCall(c, "@sqrt", &.{payload});
        },
        .trunc => {
            const payload = node.castTag(.trunc).?.data;
            return renderBuiltinCall(c, "@trunc", &.{payload});
        },
        .floor => {
            const payload = node.castTag(.floor).?.data;
            return renderBuiltinCall(c, "@floor", &.{payload});
        },
        .negate => return renderPrefixOp(c, node, .negation, .minus, "-"),
        .negate_wrap => return renderPrefixOp(c, node, .negation_wrap, .minus_percent, "-%"),
        .bit_not => return renderPrefixOp(c, node, .bit_not, .tilde, "~"),
        .not => return renderPrefixOp(c, node, .bool_not, .bang, "!"),
        .optional_type => return renderPrefixOp(c, node, .optional_type, .question_mark, "?"),
        .address_of => {
            const payload = node.castTag(.address_of).?.data;

            const ampersand = try c.addToken(.ampersand, "&");
            const base = try renderNodeGrouped(c, payload);
            return c.addNode(.{
                .tag = .address_of,
                .main_token = ampersand,
                .data = .{
                    .node = base,
                },
            });
        },
        .deref => {
            const payload = node.castTag(.deref).?.data;
            const operand = try renderNodeGrouped(c, payload);
            const deref_tok = try c.addToken(.period_asterisk, ".*");
            return c.addNode(.{
                .tag = .deref,
                .main_token = deref_tok,
                .data = .{
                    .node = operand,
                },
            });
        },
        .unwrap => {
            const payload = node.castTag(.unwrap).?.data;
            const operand = try renderNodeGrouped(c, payload);
            const period = try c.addToken(.period, ".");
            const question_mark = try c.addToken(.question_mark, "?");
            return c.addNode(.{
                .tag = .unwrap_optional,
                .main_token = period,
                .data = .{ .node_and_token = .{
                    operand, question_mark,
                } },
            });
        },
        .c_pointer, .single_pointer => {
            const payload = @as(*Payload.Pointer, @alignCast(@fieldParentPtr("base", node.ptr_otherwise))).data;

            const main_token = if (node.tag() == .single_pointer)
                try c.addToken(.asterisk, "*")
            else blk: {
                const res = try c.addToken(.l_bracket, "[");
                _ = try c.addToken(.asterisk, "*");
                _ = try c.addIdentifier("c");
                _ = try c.addToken(.r_bracket, "]");
                break :blk res;
            };
            if (payload.is_const) _ = try c.addToken(.keyword_const, "const");
            if (payload.is_volatile) _ = try c.addToken(.keyword_volatile, "volatile");
            if (payload.is_allowzero) _ = try c.addToken(.keyword_allowzero, "allowzero");
            const elem_type = try renderNodeGrouped(c, payload.elem_type);

            return c.addNode(.{
                .tag = .ptr_type_aligned,
                .main_token = main_token,
                .data = .{
                    .opt_node_and_node = .{
                        .none, // Align node
                        elem_type,
                    },
                },
            });
        },
        .add => return renderBinOpGrouped(c, node, .add, .plus, "+"),
        .add_assign => return renderBinOp(c, node, .assign_add, .plus_equal, "+="),
        .add_wrap => return renderBinOpGrouped(c, node, .add_wrap, .plus_percent, "+%"),
        .add_wrap_assign => return renderBinOp(c, node, .assign_add_wrap, .plus_percent_equal, "+%="),
        .sub => return renderBinOpGrouped(c, node, .sub, .minus, "-"),
        .sub_assign => return renderBinOp(c, node, .assign_sub, .minus_equal, "-="),
        .sub_wrap => return renderBinOpGrouped(c, node, .sub_wrap, .minus_percent, "-%"),
        .sub_wrap_assign => return renderBinOp(c, node, .assign_sub_wrap, .minus_percent_equal, "-%="),
        .mul => return renderBinOpGrouped(c, node, .mul, .asterisk, "*"),
        .mul_assign => return renderBinOp(c, node, .assign_mul, .asterisk_equal, "*="),
        .mul_wrap => return renderBinOpGrouped(c, node, .mul_wrap, .asterisk_percent, "*%"),
        .mul_wrap_assign => return renderBinOp(c, node, .assign_mul_wrap, .asterisk_percent_equal, "*%="),
        .div => return renderBinOpGrouped(c, node, .div, .slash, "/"),
        .div_assign => return renderBinOp(c, node, .assign_div, .slash_equal, "/="),
        .shl => return renderBinOpGrouped(c, node, .shl, .angle_bracket_angle_bracket_left, "<<"),
        .shl_assign => return renderBinOp(c, node, .assign_shl, .angle_bracket_angle_bracket_left_equal, "<<="),
        .shr => return renderBinOpGrouped(c, node, .shr, .angle_bracket_angle_bracket_right, ">>"),
        .shr_assign => return renderBinOp(c, node, .assign_shr, .angle_bracket_angle_bracket_right_equal, ">>="),
        .mod => return renderBinOpGrouped(c, node, .mod, .percent, "%"),
        .mod_assign => return renderBinOp(c, node, .assign_mod, .percent_equal, "%="),
        .@"and" => return renderBinOpGrouped(c, node, .bool_and, .keyword_and, "and"),
        .@"or" => return renderBinOpGrouped(c, node, .bool_or, .keyword_or, "or"),
        .less_than => return renderBinOpGrouped(c, node, .less_than, .angle_bracket_left, "<"),
        .less_than_equal => return renderBinOpGrouped(c, node, .less_or_equal, .angle_bracket_left_equal, "<="),
        .greater_than => return renderBinOpGrouped(c, node, .greater_than, .angle_bracket_right, ">="),
        .greater_than_equal => return renderBinOpGrouped(c, node, .greater_or_equal, .angle_bracket_right_equal, ">="),
        .equal => return renderBinOpGrouped(c, node, .equal_equal, .equal_equal, "=="),
        .not_equal => return renderBinOpGrouped(c, node, .bang_equal, .bang_equal, "!="),
        .bit_and => return renderBinOpGrouped(c, node, .bit_and, .ampersand, "&"),
        .bit_and_assign => return renderBinOp(c, node, .assign_bit_and, .ampersand_equal, "&="),
        .bit_or => return renderBinOpGrouped(c, node, .bit_or, .pipe, "|"),
        .bit_or_assign => return renderBinOp(c, node, .assign_bit_or, .pipe_equal, "|="),
        .bit_xor => return renderBinOpGrouped(c, node, .bit_xor, .caret, "^"),
        .bit_xor_assign => return renderBinOp(c, node, .assign_bit_xor, .caret_equal, "^="),
        .array_cat => return renderBinOp(c, node, .array_cat, .plus_plus, "++"),
        .ellipsis3 => return renderBinOpGrouped(c, node, .switch_range, .ellipsis3, "..."),
        .assign => return renderBinOp(c, node, .assign, .equal, "="),
        .empty_block => {
            const l_brace = try c.addToken(.l_brace, "{");
            _ = try c.addToken(.r_brace, "}");
            return c.addNode(.{
                .tag = .block_two,
                .main_token = l_brace,
                .data = .{ .opt_node_and_opt_node = .{
                    .none, .none,
                } },
            });
        },
        .block_single => {
            const payload = node.castTag(.block_single).?.data;
            const l_brace = try c.addToken(.l_brace, "{");

            const stmt = (try renderNodeOpt(c, payload)) orelse {
                _ = try c.addToken(.r_brace, "}");
                return c.addNode(.{
                    .tag = .block_two,
                    .main_token = l_brace,
                    .data = .{ .opt_node_and_opt_node = .{
                        .none, .none,
                    } },
                });
            };
            try addSemicolonIfNeeded(c, payload);

            _ = try c.addToken(.r_brace, "}");
            return c.addNode(.{
                .tag = .block_two_semicolon,
                .main_token = l_brace,
                .data = .{ .opt_node_and_opt_node = .{
                    stmt.toOptional(), .none,
                } },
            });
        },
        .block => {
            const payload = node.castTag(.block).?.data;
            if (payload.label) |some| {
                _ = try c.addIdentifier(some);
                _ = try c.addToken(.colon, ":");
            }
            const l_brace = try c.addToken(.l_brace, "{");

            var stmts = std.ArrayList(NodeIndex).init(c.gpa);
            defer stmts.deinit();
            for (payload.stmts) |stmt| {
                const res = (try renderNodeOpt(c, stmt)) orelse continue;
                try addSemicolonIfNeeded(c, stmt);
                try stmts.append(res);
            }
            const span = try c.listToSpan(stmts.items);
            _ = try c.addToken(.r_brace, "}");

            const semicolon = c.tokens.items(.tag)[c.tokens.len - 2] == .semicolon;
            return c.addNode(.{
                .tag = if (semicolon) .block_semicolon else .block,
                .main_token = l_brace,
                .data = .{ .extra_range = span },
            });
        },
        .func => return renderFunc(c, node),
        .pub_inline_fn => return renderMacroFunc(c, node),
        .@"while" => {
            const payload = node.castTag(.@"while").?.data;
            const while_tok = try c.addToken(.keyword_while, "while");
            _ = try c.addToken(.l_paren, "(");
            const cond = try renderNode(c, payload.cond);
            _ = try c.addToken(.r_paren, ")");

            const cont_expr_opt = if (payload.cont_expr) |some| blk: {
                _ = try c.addToken(.colon, ":");
                _ = try c.addToken(.l_paren, "(");
                const res = try renderNode(c, some);
                _ = try c.addToken(.r_paren, ")");
                break :blk res;
            } else null;
            const body = try renderNode(c, payload.body);

            if (cont_expr_opt) |cont_expr| {
                return c.addNode(.{
                    .tag = .while_cont,
                    .main_token = while_tok,
                    .data = .{ .node_and_extra = .{
                        cond,
                        try c.addExtra(std.zig.Ast.Node.WhileCont{
                            .cont_expr = cont_expr,
                            .then_expr = body,
                        }),
                    } },
                });
            } else {
                return c.addNode(.{
                    .tag = .while_simple,
                    .main_token = while_tok,
                    .data = .{ .node_and_node = .{
                        cond, body,
                    } },
                });
            }
        },
        .while_true => {
            const payload = node.castTag(.while_true).?.data;
            const while_tok = try c.addToken(.keyword_while, "while");
            _ = try c.addToken(.l_paren, "(");
            const cond = try c.addNode(.{
                .tag = .identifier,
                .main_token = try c.addToken(.identifier, "true"),
                .data = undefined,
            });
            _ = try c.addToken(.r_paren, ")");
            const body = try renderNode(c, payload);

            return c.addNode(.{
                .tag = .while_simple,
                .main_token = while_tok,
                .data = .{ .node_and_node = .{
                    cond, body,
                } },
            });
        },
        .@"if" => {
            const payload = node.castTag(.@"if").?.data;
            const if_tok = try c.addToken(.keyword_if, "if");
            _ = try c.addToken(.l_paren, "(");
            const cond = try renderNode(c, payload.cond);
            _ = try c.addToken(.r_paren, ")");

            const then_expr = try renderNode(c, payload.then);
            const else_node = payload.@"else" orelse return c.addNode(.{
                .tag = .if_simple,
                .main_token = if_tok,
                .data = .{ .node_and_node = .{
                    cond, then_expr,
                } },
            });
            _ = try c.addToken(.keyword_else, "else");
            const else_expr = try renderNode(c, else_node);

            return c.addNode(.{
                .tag = .@"if",
                .main_token = if_tok,
                .data = .{ .node_and_extra = .{
                    cond,
                    try c.addExtra(std.zig.Ast.Node.If{
                        .then_expr = then_expr,
                        .else_expr = else_expr,
                    }),
                } },
            });
        },
        .if_not_break => {
            const payload = node.castTag(.if_not_break).?.data;
            const if_tok = try c.addToken(.keyword_if, "if");
            _ = try c.addToken(.l_paren, "(");
            const cond = try c.addNode(.{
                .tag = .bool_not,
                .main_token = try c.addToken(.bang, "!"),
                .data = .{
                    .node = try renderNodeGrouped(c, payload),
                },
            });
            _ = try c.addToken(.r_paren, ")");
            const then_expr = try c.addNode(.{
                .tag = .@"break",
                .main_token = try c.addToken(.keyword_break, "break"),
                .data = .{ .opt_token_and_opt_node = .{
                    .none, .none,
                } },
            });

            return c.addNode(.{
                .tag = .if_simple,
                .main_token = if_tok,
                .data = .{ .node_and_node = .{
                    cond, then_expr,
                } },
            });
        },
        .@"switch" => {
            const payload = node.castTag(.@"switch").?.data;
            const switch_tok = try c.addToken(.keyword_switch, "switch");
            _ = try c.addToken(.l_paren, "(");
            const cond = try renderNode(c, payload.cond);
            _ = try c.addToken(.r_paren, ")");

            _ = try c.addToken(.l_brace, "{");
            var cases = try c.gpa.alloc(NodeIndex, payload.cases.len);
            defer c.gpa.free(cases);
            for (payload.cases, 0..) |case, i| {
                cases[i] = try renderNode(c, case);
                _ = try c.addToken(.comma, ",");
            }
            const span = try c.listToSpan(cases);
            _ = try c.addToken(.r_brace, "}");
            return c.addNode(.{
                .tag = .switch_comma,
                .main_token = switch_tok,
                .data = .{ .node_and_extra = .{
                    cond,
                    try c.addExtra(NodeSubRange{
                        .start = span.start,
                        .end = span.end,
                    }),
                } },
            });
        },
        .switch_else => {
            const payload = node.castTag(.switch_else).?.data;
            _ = try c.addToken(.keyword_else, "else");
            return c.addNode(.{
                .tag = .switch_case_one,
                .main_token = try c.addToken(.equal_angle_bracket_right, "=>"),
                .data = .{ .opt_node_and_node = .{
                    .none, try renderNode(c, payload),
                } },
            });
        },
        .switch_prong => {
            const payload = node.castTag(.switch_prong).?.data;
            var items = try c.gpa.alloc(NodeIndex, payload.cases.len);
            defer c.gpa.free(items);

            for (payload.cases, 0..) |item, i| {
                if (i != 0) _ = try c.addToken(.comma, ",");
                items[i] = try renderNode(c, item);
            }
            _ = try c.addToken(.r_brace, "}");
            if (items.len < 2) {
                return c.addNode(.{
                    .tag = .switch_case_one,
                    .main_token = try c.addToken(.equal_angle_bracket_right, "=>"),
                    .data = .{ .opt_node_and_node = .{
                        if (payload.cases.len == 1) items[0].toOptional() else .none,
                        try renderNode(c, payload.cond),
                    } },
                });
            } else {
                return c.addNode(.{
                    .tag = .switch_case,
                    .main_token = try c.addToken(.equal_angle_bracket_right, "=>"),
                    .data = .{ .extra_and_node = .{
                        try c.addExtra(try c.listToSpan(items)),
                        try renderNode(c, payload.cond),
                    } },
                });
            }
        },
        .opaque_literal => {
            const opaque_tok = try c.addToken(.keyword_opaque, "opaque");
            _ = try c.addToken(.l_brace, "{");
            _ = try c.addToken(.r_brace, "}");

            return c.addNode(.{
                .tag = .container_decl_two,
                .main_token = opaque_tok,
                .data = .{ .opt_node_and_opt_node = .{
                    .none, .none,
                } },
            });
        },
        .array_access => {
            const payload = node.castTag(.array_access).?.data;
            const lhs = try renderNodeGrouped(c, payload.lhs);
            const l_bracket = try c.addToken(.l_bracket, "[");
            const index_expr = try renderNode(c, payload.rhs);
            _ = try c.addToken(.r_bracket, "]");
            return c.addNode(.{
                .tag = .array_access,
                .main_token = l_bracket,
                .data = .{ .node_and_node = .{
                    lhs, index_expr,
                } },
            });
        },
        .array_type => {
            const payload = node.castTag(.array_type).?.data;
            return renderArrayType(c, payload.len, payload.elem_type);
        },
        .null_sentinel_array_type => {
            const payload = node.castTag(.null_sentinel_array_type).?.data;
            return renderNullSentinelArrayType(c, payload.len, payload.elem_type);
        },
        .array_filler => {
            const payload = node.castTag(.array_filler).?.data;

            const type_expr = try renderArrayType(c, 1, payload.type);
            const l_brace = try c.addToken(.l_brace, "{");
            const val = try renderNode(c, payload.filler);
            _ = try c.addToken(.r_brace, "}");

            const init = try c.addNode(.{
                .tag = .array_init_one,
                .main_token = l_brace,
                .data = .{ .node_and_node = .{
                    type_expr, val,
                } },
            });
            return c.addNode(.{
                .tag = .array_cat,
                .main_token = try c.addToken(.asterisk_asterisk, "**"),
                .data = .{ .node_and_node = .{
                    init,
                    try c.addNode(.{
                        .tag = .number_literal,
                        .main_token = try c.addTokenFmt(.number_literal, "{d}", .{payload.count}),
                        .data = undefined,
                    }),
                } },
            });
        },
        .empty_array => {
            const payload = node.castTag(.empty_array).?.data;

            const type_expr = try renderNode(c, payload);
            return renderArrayInit(c, type_expr, &.{});
        },
        .array_init => {
            const payload = node.castTag(.array_init).?.data;
            const type_expr = try renderNode(c, payload.cond);
            return renderArrayInit(c, type_expr, payload.cases);
        },
        .vector_zero_init => {
            const payload = node.castTag(.vector_zero_init).?.data;
            return renderBuiltinCall(c, "@splat", &.{payload});
        },
        .field_access => {
            const payload = node.castTag(.field_access).?.data;
            const lhs = try renderNodeGrouped(c, payload.lhs);
            return renderFieldAccess(c, lhs, payload.field_name);
        },
        .@"struct", .@"union", .@"opaque" => return renderContainer(c, node),
        .enum_constant => {
            const payload = node.castTag(.enum_constant).?.data;

            if (payload.is_public) _ = try c.addToken(.keyword_pub, "pub");
            const const_tok = try c.addToken(.keyword_const, "const");
            _ = try c.addIdentifier(payload.name);

            const type_node_opt = if (payload.type) |enum_const_type| blk: {
                _ = try c.addToken(.colon, ":");
                break :blk try renderNode(c, enum_const_type);
            } else null;

            _ = try c.addToken(.equal, "=");

            const init_node = try renderNode(c, payload.value);
            _ = try c.addToken(.semicolon, ";");

            return c.addNode(.{
                .tag = .simple_var_decl,
                .main_token = const_tok,
                .data = .{ .opt_node_and_opt_node = .{
                    .fromOptional(type_node_opt),
                    init_node.toOptional(),
                } },
            });
        },
        .tuple => {
            const payload = node.castTag(.tuple).?.data;
            _ = try c.addToken(.period, ".");
            const l_brace = try c.addToken(.l_brace, "{");
            var inits = try c.gpa.alloc(NodeIndex, payload.len);
            defer c.gpa.free(inits);

            for (payload, 0..) |init, i| {
                if (i != 0) _ = try c.addToken(.comma, ",");
                inits[i] = try renderNode(c, init);
            }
            _ = try c.addToken(.r_brace, "}");
            if (payload.len < 3) {
                return c.addNode(.{
                    .tag = .array_init_dot_two,
                    .main_token = l_brace,
                    .data = .{ .opt_node_and_opt_node = .{
                        if (inits.len >= 1) inits[0].toOptional() else .none,
                        if (inits.len >= 2) inits[1].toOptional() else .none,
                    } },
                });
            } else {
                return c.addNode(.{
                    .tag = .array_init_dot,
                    .main_token = l_brace,
                    .data = .{ .extra_range = try c.listToSpan(inits) },
                });
            }
        },
        .container_init_dot => {
            const payload = node.castTag(.container_init_dot).?.data;
            _ = try c.addToken(.period, ".");
            const l_brace = try c.addToken(.l_brace, "{");
            var inits = try c.gpa.alloc(NodeIndex, payload.len);
            defer c.gpa.free(inits);

            for (payload, 0..) |init, i| {
                _ = try c.addToken(.period, ".");
                _ = try c.addIdentifier(init.name);
                _ = try c.addToken(.equal, "=");
                inits[i] = try renderNode(c, init.value);
                _ = try c.addToken(.comma, ",");
            }
            _ = try c.addToken(.r_brace, "}");

            if (payload.len < 3) {
                return c.addNode(.{
                    .tag = .struct_init_dot_two_comma,
                    .main_token = l_brace,
                    .data = .{ .opt_node_and_opt_node = .{
                        if (inits.len >= 1) inits[0].toOptional() else .none,
                        if (inits.len >= 2) inits[1].toOptional() else .none,
                    } },
                });
            } else {
                return c.addNode(.{
                    .tag = .struct_init_dot_comma,
                    .main_token = l_brace,
                    .data = .{ .extra_range = try c.listToSpan(inits) },
                });
            }
        },
        .container_init => {
            const payload = node.castTag(.container_init).?.data;
            const lhs = try renderNode(c, payload.lhs);

            const l_brace = try c.addToken(.l_brace, "{");
            var inits = try c.gpa.alloc(NodeIndex, payload.inits.len);
            defer c.gpa.free(inits);

            for (payload.inits, 0..) |init, i| {
                _ = try c.addToken(.period, ".");
                _ = try c.addIdentifier(init.name);
                _ = try c.addToken(.equal, "=");
                inits[i] = try renderNode(c, init.value);
                _ = try c.addToken(.comma, ",");
            }
            _ = try c.addToken(.r_brace, "}");

            switch (inits.len) {
                0 => return c.addNode(.{
                    .tag = .struct_init_one,
                    .main_token = l_brace,
                    .data = .{ .node_and_opt_node = .{
                        lhs, .none,
                    } },
                }),
                1 => return c.addNode(.{
                    .tag = .struct_init_one_comma,
                    .main_token = l_brace,
                    .data = .{ .node_and_opt_node = .{
                        lhs, inits[0].toOptional(),
                    } },
                }),
                else => return c.addNode(.{
                    .tag = .struct_init_comma,
                    .main_token = l_brace,
                    .data = .{ .node_and_extra = .{
                        lhs,
                        try c.addExtra(try c.listToSpan(inits)),
                    } },
                }),
            }
        },
        .static_assert => {
            const payload = node.castTag(.static_assert).?.data;
            const comptime_tok = try c.addToken(.keyword_comptime, "comptime");
            const l_brace = try c.addToken(.l_brace, "{");

            const if_tok = try c.addToken(.keyword_if, "if");
            _ = try c.addToken(.l_paren, "(");
            const cond = try c.addNode(.{
                .tag = .bool_not,
                .main_token = try c.addToken(.bang, "!"),
                .data = .{
                    .node = try renderNodeGrouped(c, payload.lhs),
                },
            });
            _ = try c.addToken(.r_paren, ")");

            const compile_error_tok = try c.addToken(.builtin, "@compileError");
            _ = try c.addToken(.l_paren, "(");
            const err_msg = try renderNode(c, payload.rhs);
            _ = try c.addToken(.r_paren, ")");
            const compile_error = try c.addNode(.{
                .tag = .builtin_call_two,
                .main_token = compile_error_tok,
                .data = .{ .opt_node_and_opt_node = .{
                    err_msg.toOptional(), .none,
                } },
            });

            const if_node = try c.addNode(.{
                .tag = .if_simple,
                .main_token = if_tok,
                .data = .{ .node_and_node = .{
                    cond, compile_error,
                } },
            });
            _ = try c.addToken(.semicolon, ";");
            _ = try c.addToken(.r_brace, "}");
            const block_node = try c.addNode(.{
                .tag = .block_two_semicolon,
                .main_token = l_brace,
                .data = .{ .opt_node_and_opt_node = .{
                    if_node.toOptional(), .none,
                } },
            });

            return c.addNode(.{
                .tag = .@"comptime",
                .main_token = comptime_tok,
                .data = .{
                    .node = block_node,
                },
            });
        },
        .@"anytype" => unreachable, // Handled in renderParams
    }
}

fn renderContainer(c: *Context, node: Node) !NodeIndex {
    const payload = @as(*Payload.Container, @alignCast(@fieldParentPtr("base", node.ptr_otherwise))).data;
    if (payload.layout == .@"packed")
        _ = try c.addToken(.keyword_packed, "packed")
    else if (payload.layout == .@"extern")
        _ = try c.addToken(.keyword_extern, "extern");
    const kind_tok = if (node.tag() == .@"struct")
        try c.addToken(.keyword_struct, "struct")
    else if (node.tag() == .@"union")
        try c.addToken(.keyword_union, "union")
    else if (node.tag() == .@"opaque")
        try c.addToken(.keyword_opaque, "opaque")
    else
        unreachable;

    _ = try c.addToken(.l_brace, "{");

    const num_decls = payload.decls.len;
    const total_members = payload.fields.len + num_decls;
    const members = try c.gpa.alloc(NodeIndex, total_members);
    defer c.gpa.free(members);

    for (payload.fields, 0..) |field, i| {
        const name_tok = try c.addTokenFmt(.identifier, "{f}", .{std.zig.fmtIdFlags(field.name, .{ .allow_primitive = true })});
        _ = try c.addToken(.colon, ":");
        const type_expr = try renderNode(c, field.type);

        const align_expr_opt = if (field.alignment) |alignment| blk: {
            _ = try c.addToken(.keyword_align, "align");
            _ = try c.addToken(.l_paren, "(");
            const align_expr = try c.addNode(.{
                .tag = .number_literal,
                .main_token = try c.addTokenFmt(.number_literal, "{d}", .{alignment}),
                .data = undefined,
            });
            _ = try c.addToken(.r_paren, ")");
            break :blk align_expr;
        } else null;

        const value_expr_opt = if (field.default_value) |value| blk: {
            _ = try c.addToken(.equal, "=");
            break :blk try renderNode(c, value);
        } else null;

        if (align_expr_opt) |align_expr| {
            if (value_expr_opt) |value_expr| {
                members[i] = try c.addNode(.{
                    .tag = .container_field,
                    .main_token = name_tok,
                    .data = .{ .node_and_extra = .{
                        type_expr,
                        try c.addExtra(std.zig.Ast.Node.ContainerField{
                            .align_expr = align_expr,
                            .value_expr = value_expr,
                        }),
                    } },
                });
            } else {
                members[i] = try c.addNode(.{
                    .tag = .container_field_align,
                    .main_token = name_tok,
                    .data = .{ .node_and_node = .{
                        type_expr,
                        align_expr,
                    } },
                });
            }
        } else {
            members[i] = try c.addNode(.{
                .tag = .container_field_init,
                .main_token = name_tok,
                .data = .{ .node_and_opt_node = .{
                    type_expr,
                    .fromOptional(value_expr_opt),
                } },
            });
        }
        _ = try c.addToken(.comma, ",");
    }
    for (members[payload.fields.len..], payload.decls) |*member, decl| {
        member.* = try renderNode(c, decl);
    }
    const trailing = switch (c.tokens.items(.tag)[c.tokens.len - 1]) {
        .comma, .semicolon => true,
        else => false,
    };
    _ = try c.addToken(.r_brace, "}");

    if (total_members == 0) {
        return c.addNode(.{
            .tag = .container_decl_two,
            .main_token = kind_tok,
            .data = .{ .opt_node_and_opt_node = .{
                .none, .none,
            } },
        });
    } else if (total_members <= 2) {
        return c.addNode(.{
            .tag = if (trailing) .container_decl_two_trailing else .container_decl_two,
            .main_token = kind_tok,
            .data = .{ .opt_node_and_opt_node = .{
                if (members.len >= 1) members[0].toOptional() else .none,
                if (members.len >= 2) members[1].toOptional() else .none,
            } },
        });
    } else {
        const span = try c.listToSpan(members);
        return c.addNode(.{
            .tag = if (trailing) .container_decl_trailing else .container_decl,
            .main_token = kind_tok,
            .data = .{ .extra_range = span },
        });
    }
}

fn renderFieldAccess(c: *Context, lhs: NodeIndex, field_name: []const u8) !NodeIndex {
    return c.addNode(.{
        .tag = .field_access,
        .main_token = try c.addToken(.period, "."),
        .data = .{ .node_and_token = .{
            lhs, try c.addTokenFmt(.identifier, "{f}", .{std.zig.fmtIdFlags(field_name, .{ .allow_primitive = true })}),
        } },
    });
}

fn renderArrayInit(c: *Context, lhs: NodeIndex, inits: []const Node) !NodeIndex {
    const l_brace = try c.addToken(.l_brace, "{");
    var rendered = try c.gpa.alloc(NodeIndex, inits.len);
    defer c.gpa.free(rendered);

    for (inits, 0..) |init, i| {
        rendered[i] = try renderNode(c, init);
        _ = try c.addToken(.comma, ",");
    }
    _ = try c.addToken(.r_brace, "}");
    switch (inits.len) {
        0 => return c.addNode(.{
            .tag = .struct_init_one,
            .main_token = l_brace,
            .data = .{ .node_and_opt_node = .{
                lhs, .none,
            } },
        }),
        1 => return c.addNode(.{
            .tag = .array_init_one_comma,
            .main_token = l_brace,
            .data = .{ .node_and_node = .{
                lhs, rendered[0],
            } },
        }),
        else => return c.addNode(.{
            .tag = .array_init_comma,
            .main_token = l_brace,
            .data = .{ .node_and_extra = .{
                lhs,
                try c.addExtra(try c.listToSpan(rendered)),
            } },
        }),
    }
}

fn renderArrayType(c: *Context, len: u64, elem_type: Node) !NodeIndex {
    const l_bracket = try c.addToken(.l_bracket, "[");
    const len_expr = try c.addNode(.{
        .tag = .number_literal,
        .main_token = try c.addTokenFmt(.number_literal, "{d}", .{len}),
        .data = undefined,
    });
    _ = try c.addToken(.r_bracket, "]");
    const elem_type_expr = try renderNode(c, elem_type);
    return c.addNode(.{
        .tag = .array_type,
        .main_token = l_bracket,
        .data = .{ .node_and_node = .{
            len_expr, elem_type_expr,
        } },
    });
}

fn renderNullSentinelArrayType(c: *Context, len: u64, elem_type: Node) !NodeIndex {
    const l_bracket = try c.addToken(.l_bracket, "[");
    const len_expr = try c.addNode(.{
        .tag = .number_literal,
        .main_token = try c.addTokenFmt(.number_literal, "{d}", .{len}),
        .data = undefined,
    });
    _ = try c.addToken(.colon, ":");

    const sentinel_expr = try c.addNode(.{
        .tag = .number_literal,
        .main_token = try c.addToken(.number_literal, "0"),
        .data = undefined,
    });

    _ = try c.addToken(.r_bracket, "]");
    const elem_type_expr = try renderNode(c, elem_type);
    return c.addNode(.{
        .tag = .array_type_sentinel,
        .main_token = l_bracket,
        .data = .{ .node_and_extra = .{
            len_expr,
            try c.addExtra(std.zig.Ast.Node.ArrayTypeSentinel{
                .sentinel = sentinel_expr,
                .elem_type = elem_type_expr,
            }),
        } },
    });
}

fn addSemicolonIfNeeded(c: *Context, node: Node) !void {
    switch (node.tag()) {
        .warning => unreachable,
        .var_decl, .var_simple, .arg_redecl, .alias, .block, .empty_block, .block_single, .@"switch", .wrapped_local, .mut_str => {},
        .while_true => {
            const payload = node.castTag(.while_true).?.data;
            return addSemicolonIfNotBlock(c, payload);
        },
        .@"while" => {
            const payload = node.castTag(.@"while").?.data;
            return addSemicolonIfNotBlock(c, payload.body);
        },
        .@"if" => {
            const payload = node.castTag(.@"if").?.data;
            if (payload.@"else") |some|
                return addSemicolonIfNeeded(c, some);
            return addSemicolonIfNotBlock(c, payload.then);
        },
        else => _ = try c.addToken(.semicolon, ";"),
    }
}

fn addSemicolonIfNotBlock(c: *Context, node: Node) !void {
    switch (node.tag()) {
        .block, .empty_block, .block_single => {},
        else => _ = try c.addToken(.semicolon, ";"),
    }
}

fn renderNodeGrouped(c: *Context, node: Node) !NodeIndex {
    switch (node.tag()) {
        .declaration => unreachable,
        .null_literal,
        .undefined_literal,
        .true_literal,
        .false_literal,
        .return_void,
        .zero_literal,
        .one_literal,
        .void_type,
        .noreturn_type,
        .@"anytype",
        .div_trunc,
        .int_cast,
        .const_cast,
        .volatile_cast,
        .as,
        .truncate,
        .bit_cast,
        .float_cast,
        .int_from_float,
        .float_from_int,
        .ptr_from_int,
        .std_mem_zeroes,
        .int_from_ptr,
        .sizeof,
        .alignof,
        .typeof,
        .typeinfo,
        .vector,
        .std_mem_zeroinit,
        .integer_literal,
        .float_literal,
        .string_literal,
        .string_slice,
        .char_literal,
        .enum_literal,
        .identifier,
        .field_access,
        .ptr_cast,
        .type,
        .array_access,
        .align_cast,
        .optional_type,
        .c_pointer,
        .single_pointer,
        .unwrap,
        .deref,
        .not,
        .negate,
        .negate_wrap,
        .bit_not,
        .func,
        .call,
        .array_type,
        .null_sentinel_array_type,
        .int_from_bool,
        .div_exact,
        .offset_of,
        .shuffle,
        .builtin_extern,
        .wrapped_local,
        .mut_str,
        .helper_call,
        .helper_ref,
        .byte_swap,
        .ceil,
        .cos,
        .sin,
        .exp,
        .exp2,
        .exp10,
        .abs,
        .log,
        .log2,
        .log10,
        .round,
        .sqrt,
        .trunc,
        .floor,
        => {
            // no grouping needed
            return renderNode(c, node);
        },

        .opaque_literal,
        .@"opaque",
        .empty_array,
        .block_single,
        .add,
        .add_wrap,
        .sub,
        .sub_wrap,
        .mul,
        .mul_wrap,
        .div,
        .shl,
        .shr,
        .mod,
        .@"and",
        .@"or",
        .less_than,
        .less_than_equal,
        .greater_than,
        .greater_than_equal,
        .equal,
        .not_equal,
        .bit_and,
        .bit_or,
        .bit_xor,
        .empty_block,
        .array_cat,
        .array_filler,
        .@"if",
        .@"struct",
        .@"union",
        .array_init,
        .vector_zero_init,
        .tuple,
        .container_init,
        .container_init_dot,
        .block,
        .address_of,
        => return c.addNode(.{
            .tag = .grouped_expression,
            .main_token = try c.addToken(.l_paren, "("),
            .data = .{ .node_and_token = .{
                try renderNode(c, node),
                try c.addToken(.r_paren, ")"),
            } },
        }),
        .ellipsis3,
        .switch_prong,
        .warning,
        .var_decl,
        .fail_decl,
        .arg_redecl,
        .alias,
        .var_simple,
        .pub_var_simple,
        .enum_constant,
        .@"while",
        .@"switch",
        .@"break",
        .break_val,
        .pub_inline_fn,
        .discard,
        .@"continue",
        .@"return",
        .@"comptime",
        .@"defer",
        .asm_simple,
        .while_true,
        .if_not_break,
        .switch_else,
        .add_assign,
        .add_wrap_assign,
        .sub_assign,
        .sub_wrap_assign,
        .mul_assign,
        .mul_wrap_assign,
        .div_assign,
        .shl_assign,
        .shr_assign,
        .mod_assign,
        .bit_and_assign,
        .bit_or_assign,
        .bit_xor_assign,
        .assign,
        .static_assert,
        .@"unreachable",
        => {
            // these should never appear in places where grouping might be needed.
            unreachable;
        },
    }
}

fn renderPrefixOp(c: *Context, node: Node, tag: std.zig.Ast.Node.Tag, tok_tag: TokenTag, bytes: []const u8) !NodeIndex {
    const payload = @as(*Payload.UnOp, @alignCast(@fieldParentPtr("base", node.ptr_otherwise))).data;
    return c.addNode(.{
        .tag = tag,
        .main_token = try c.addToken(tok_tag, bytes),
        .data = .{
            .node = try renderNodeGrouped(c, payload),
        },
    });
}

fn renderBinOpGrouped(c: *Context, node: Node, tag: std.zig.Ast.Node.Tag, tok_tag: TokenTag, bytes: []const u8) !NodeIndex {
    const payload = @as(*Payload.BinOp, @alignCast(@fieldParentPtr("base", node.ptr_otherwise))).data;
    const lhs = try renderNodeGrouped(c, payload.lhs);
    return c.addNode(.{
        .tag = tag,
        .main_token = try c.addToken(tok_tag, bytes),
        .data = .{ .node_and_node = .{
            lhs, try renderNodeGrouped(c, payload.rhs),
        } },
    });
}

fn renderBinOp(c: *Context, node: Node, tag: std.zig.Ast.Node.Tag, tok_tag: TokenTag, bytes: []const u8) !NodeIndex {
    const payload = @as(*Payload.BinOp, @alignCast(@fieldParentPtr("base", node.ptr_otherwise))).data;
    const lhs = try renderNode(c, payload.lhs);
    return c.addNode(.{
        .tag = tag,
        .main_token = try c.addToken(tok_tag, bytes),
        .data = .{ .node_and_node = .{
            lhs, try renderNode(c, payload.rhs),
        } },
    });
}

fn renderStdImport(c: *Context, parts: []const []const u8) !NodeIndex {
    const import_tok = try c.addToken(.builtin, "@import");
    _ = try c.addToken(.l_paren, "(");
    const std_tok = try c.addToken(.string_literal, "\"std\"");
    const std_node = try c.addNode(.{
        .tag = .string_literal,
        .main_token = std_tok,
        .data = undefined,
    });
    _ = try c.addToken(.r_paren, ")");

    const import_node = try c.addNode(.{
        .tag = .builtin_call_two,
        .main_token = import_tok,
        .data = .{ .opt_node_and_opt_node = .{
            std_node.toOptional(), .none,
        } },
    });

    var access_chain = import_node;
    for (parts) |part| {
        access_chain = try renderFieldAccess(c, access_chain, part);
    }
    return access_chain;
}

fn renderCall(c: *Context, lhs: NodeIndex, args: []const Node) !NodeIndex {
    const lparen = try c.addToken(.l_paren, "(");
    const res = switch (args.len) {
        0 => try c.addNode(.{
            .tag = .call_one,
            .main_token = lparen,
            .data = .{ .node_and_opt_node = .{
                lhs, .none,
            } },
        }),
        1 => try c.addNode(.{
            .tag = .call_one,
            .main_token = lparen,
            .data = .{ .node_and_opt_node = .{
                lhs, (try renderNode(c, args[0])).toOptional(),
            } },
        }),
        else => blk: {
            var rendered = try c.gpa.alloc(NodeIndex, args.len);
            defer c.gpa.free(rendered);

            for (args, 0..) |arg, i| {
                if (i != 0) _ = try c.addToken(.comma, ",");
                rendered[i] = try renderNode(c, arg);
            }
            const span = try c.listToSpan(rendered);
            break :blk try c.addNode(.{
                .tag = .call,
                .main_token = lparen,
                .data = .{ .node_and_extra = .{
                    lhs, try c.addExtra(NodeSubRange{
                        .start = span.start,
                        .end = span.end,
                    }),
                } },
            });
        },
    };
    _ = try c.addToken(.r_paren, ")");
    return res;
}

fn renderBuiltinCall(c: *Context, builtin: []const u8, args: []const Node) !NodeIndex {
    const builtin_tok = try c.addToken(.builtin, builtin);
    _ = try c.addToken(.l_paren, "(");
    var arg_1: ?NodeIndex = null;
    var arg_2: ?NodeIndex = null;
    var arg_3: ?NodeIndex = null;
    var arg_4: ?NodeIndex = null;
    switch (args.len) {
        0 => {},
        1 => {
            arg_1 = try renderNode(c, args[0]);
        },
        2 => {
            arg_1 = try renderNode(c, args[0]);
            _ = try c.addToken(.comma, ",");
            arg_2 = try renderNode(c, args[1]);
        },
        4 => {
            arg_1 = try renderNode(c, args[0]);
            _ = try c.addToken(.comma, ",");
            arg_2 = try renderNode(c, args[1]);
            _ = try c.addToken(.comma, ",");
            arg_3 = try renderNode(c, args[2]);
            _ = try c.addToken(.comma, ",");
            arg_4 = try renderNode(c, args[3]);
        },
        else => unreachable, // expand this function as needed.
    }

    _ = try c.addToken(.r_paren, ")");
    if (args.len <= 2) {
        return c.addNode(.{
            .tag = .builtin_call_two,
            .main_token = builtin_tok,
            .data = .{ .opt_node_and_opt_node = .{
                .fromOptional(arg_1), .fromOptional(arg_2),
            } },
        });
    } else {
        std.debug.assert(args.len == 4);

        const params = try c.listToSpan(&.{ arg_1.?, arg_2.?, arg_3.?, arg_4.? });
        return c.addNode(.{
            .tag = .builtin_call,
            .main_token = builtin_tok,
            .data = .{ .extra_range = .{
                .start = params.start,
                .end = params.end,
            } },
        });
    }
}

fn renderVar(c: *Context, node: Node) !NodeIndex {
    const payload = node.castTag(.var_decl).?.data;
    if (payload.is_pub) _ = try c.addToken(.keyword_pub, "pub");
    if (payload.is_extern) _ = try c.addToken(.keyword_extern, "extern");
    if (payload.is_export) _ = try c.addToken(.keyword_export, "export");
    if (payload.is_threadlocal) _ = try c.addToken(.keyword_threadlocal, "threadlocal");
    const mut_tok = if (payload.is_const)
        try c.addToken(.keyword_const, "const")
    else
        try c.addToken(.keyword_var, "var");
    _ = try c.addIdentifier(payload.name);
    _ = try c.addToken(.colon, ":");
    const type_node = try renderNode(c, payload.type);

    const align_node_opt = if (payload.alignment) |some| blk: {
        _ = try c.addToken(.keyword_align, "align");
        _ = try c.addToken(.l_paren, "(");
        const res = try c.addNode(.{
            .tag = .number_literal,
            .main_token = try c.addTokenFmt(.number_literal, "{d}", .{some}),
            .data = undefined,
        });
        _ = try c.addToken(.r_paren, ")");
        break :blk res;
    } else null;

    const section_node_opt = if (payload.linksection_string) |some| blk: {
        _ = try c.addToken(.keyword_linksection, "linksection");
        _ = try c.addToken(.l_paren, "(");
        const res = try c.addNode(.{
            .tag = .string_literal,
            .main_token = try c.addTokenFmt(.string_literal, "\"{f}\"", .{std.zig.fmtString(some)}),
            .data = undefined,
        });
        _ = try c.addToken(.r_paren, ")");
        break :blk res;
    } else null;

    const init_node_opt = if (payload.init) |some| blk: {
        _ = try c.addToken(.equal, "=");
        break :blk try renderNode(c, some);
    } else null;
    _ = try c.addToken(.semicolon, ";");

    if (section_node_opt) |section_node| {
        return c.addNode(.{
            .tag = .global_var_decl,
            .main_token = mut_tok,
            .data = .{ .extra_and_opt_node = .{
                try c.addExtra(std.zig.Ast.Node.GlobalVarDecl{
                    .type_node = type_node.toOptional(),
                    .align_node = .fromOptional(align_node_opt),
                    .section_node = section_node.toOptional(),
                    .addrspace_node = .none,
                }),
                .fromOptional(init_node_opt),
            } },
        });
    } else {
        if (align_node_opt) |align_node| {
            return c.addNode(.{
                .tag = .local_var_decl,
                .main_token = mut_tok,
                .data = .{ .extra_and_opt_node = .{
                    try c.addExtra(std.zig.Ast.Node.LocalVarDecl{
                        .type_node = type_node,
                        .align_node = align_node,
                    }),
                    .fromOptional(init_node_opt),
                } },
            });
        } else {
            return c.addNode(.{
                .tag = .simple_var_decl,
                .main_token = mut_tok,
                .data = .{
                    .opt_node_and_opt_node = .{
                        type_node.toOptional(), // Type expression
                        .fromOptional(init_node_opt), // Init expression
                    },
                },
            });
        }
    }
}

fn renderFunc(c: *Context, node: Node) !NodeIndex {
    const payload = node.castTag(.func).?.data;
    if (payload.is_pub) _ = try c.addToken(.keyword_pub, "pub");
    if (payload.is_extern) _ = try c.addToken(.keyword_extern, "extern");
    if (payload.is_export) _ = try c.addToken(.keyword_export, "export");
    if (payload.is_inline) _ = try c.addToken(.keyword_inline, "inline");
    const fn_token = try c.addToken(.keyword_fn, "fn");
    if (payload.name) |some| _ = try c.addIdentifier(some);

    const params = try renderParams(c, payload.params, payload.is_var_args);
    defer params.deinit();
    var span: NodeSubRange = undefined;
    if (params.items.len > 1) span = try c.listToSpan(params.items);

    const align_expr_opt = if (payload.alignment) |some| blk: {
        _ = try c.addToken(.keyword_align, "align");
        _ = try c.addToken(.l_paren, "(");
        const res = try c.addNode(.{
            .tag = .number_literal,
            .main_token = try c.addTokenFmt(.number_literal, "{d}", .{some}),
            .data = undefined,
        });
        _ = try c.addToken(.r_paren, ")");
        break :blk res;
    } else null;

    const section_expr_opt = if (payload.linksection_string) |some| blk: {
        _ = try c.addToken(.keyword_linksection, "linksection");
        _ = try c.addToken(.l_paren, "(");
        const res = try c.addNode(.{
            .tag = .string_literal,
            .main_token = try c.addTokenFmt(.string_literal, "\"{f}\"", .{std.zig.fmtString(some)}),
            .data = undefined,
        });
        _ = try c.addToken(.r_paren, ")");
        break :blk res;
    } else null;

    const callconv_expr_opt = if (payload.explicit_callconv) |some| blk: {
        _ = try c.addToken(.keyword_callconv, "callconv");
        _ = try c.addToken(.l_paren, "(");
        const cc_node = switch (some) {
            .c => cc_node: {
                _ = try c.addToken(.period, ".");
                break :cc_node try c.addNode(.{
                    .tag = .enum_literal,
                    .main_token = try c.addToken(.identifier, "c"),
                    .data = undefined,
                });
            },
            .x86_64_sysv,
            .x86_64_win,
            .x86_stdcall,
            .x86_fastcall,
            .x86_thiscall,
            .x86_vectorcall,
            .x86_regcall,
            .aarch64_vfabi,
            .aarch64_sve_pcs,
            .arm_aapcs,
            .arm_aapcs_vfp,
            .m68k_rtd,
            .riscv_vector,
            => cc_node: {
                // .{ .foo = .{} }
                _ = try c.addToken(.period, ".");
                const outer_lbrace = try c.addToken(.l_brace, "{");
                _ = try c.addToken(.period, ".");
                _ = try c.addToken(.identifier, @tagName(some));
                _ = try c.addToken(.equal, "=");
                _ = try c.addToken(.period, ".");
                const inner_lbrace = try c.addToken(.l_brace, "{");
                _ = try c.addToken(.r_brace, "}");
                _ = try c.addToken(.r_brace, "}");
                break :cc_node try c.addNode(.{
                    .tag = .struct_init_dot_two,
                    .main_token = outer_lbrace,
                    .data = .{ .opt_node_and_opt_node = .{
                        (try c.addNode(.{
                            .tag = .struct_init_dot_two,
                            .main_token = inner_lbrace,
                            .data = .{ .opt_node_and_opt_node = .{
                                .none, .none,
                            } },
                        })).toOptional(),
                        .none,
                    } },
                });
            },
        };
        _ = try c.addToken(.r_paren, ")");
        break :blk cc_node;
    } else null;

    const return_type_expr = try renderNode(c, payload.return_type);

    const fn_proto = try blk: {
        if (align_expr_opt == null and section_expr_opt == null and callconv_expr_opt == null) {
            if (params.items.len < 2)
                break :blk c.addNode(.{
                    .tag = .fn_proto_simple,
                    .main_token = fn_token,
                    .data = .{ .opt_node_and_opt_node = .{
                        if (params.items.len == 1) params.items[0].toOptional() else .none,
                        return_type_expr.toOptional(),
                    } },
                })
            else
                break :blk c.addNode(.{
                    .tag = .fn_proto_multi,
                    .main_token = fn_token,
                    .data = .{ .extra_and_opt_node = .{
                        try c.addExtra(span),
                        return_type_expr.toOptional(),
                    } },
                });
        }
        if (params.items.len < 2)
            break :blk c.addNode(.{
                .tag = .fn_proto_one,
                .main_token = fn_token,
                .data = .{
                    .extra_and_opt_node = .{
                        try c.addExtra(std.zig.Ast.Node.FnProtoOne{
                            .param = if (params.items.len == 1) params.items[0].toOptional() else .none,
                            .align_expr = .fromOptional(align_expr_opt),
                            .addrspace_expr = .none, // TODO
                            .section_expr = .fromOptional(section_expr_opt),
                            .callconv_expr = .fromOptional(callconv_expr_opt),
                        }),
                        return_type_expr.toOptional(),
                    },
                },
            })
        else
            break :blk c.addNode(.{
                .tag = .fn_proto,
                .main_token = fn_token,
                .data = .{
                    .extra_and_opt_node = .{
                        try c.addExtra(std.zig.Ast.Node.FnProto{
                            .params_start = span.start,
                            .params_end = span.end,
                            .align_expr = .fromOptional(align_expr_opt),
                            .addrspace_expr = .none, // TODO
                            .section_expr = .fromOptional(section_expr_opt),
                            .callconv_expr = .fromOptional(callconv_expr_opt),
                        }),
                        return_type_expr.toOptional(),
                    },
                },
            });
    };

    const payload_body = payload.body orelse {
        if (payload.is_extern) {
            _ = try c.addToken(.semicolon, ";");
        }
        return fn_proto;
    };
    const body = try renderNode(c, payload_body);
    return c.addNode(.{
        .tag = .fn_decl,
        .main_token = fn_token,
        .data = .{ .node_and_node = .{
            fn_proto, body,
        } },
    });
}

fn renderMacroFunc(c: *Context, node: Node) !NodeIndex {
    const payload = node.castTag(.pub_inline_fn).?.data;
    _ = try c.addToken(.keyword_pub, "pub");
    _ = try c.addToken(.keyword_inline, "inline");
    const fn_token = try c.addToken(.keyword_fn, "fn");
    _ = try c.addIdentifier(payload.name);

    const params = try renderParams(c, payload.params, false);
    defer params.deinit();
    var span: NodeSubRange = undefined;
    if (params.items.len > 1) span = try c.listToSpan(params.items);

    const return_type_expr = try renderNodeGrouped(c, payload.return_type);

    const fn_proto = blk: {
        if (params.items.len < 2) {
            break :blk try c.addNode(.{
                .tag = .fn_proto_simple,
                .main_token = fn_token,
                .data = .{ .opt_node_and_opt_node = .{
                    if (params.items.len == 1) params.items[0].toOptional() else .none,
                    return_type_expr.toOptional(),
                } },
            });
        } else {
            break :blk try c.addNode(.{
                .tag = .fn_proto_multi,
                .main_token = fn_token,
                .data = .{ .extra_and_opt_node = .{
                    try c.addExtra(span),
                    return_type_expr.toOptional(),
                } },
            });
        }
    };
    return c.addNode(.{
        .tag = .fn_decl,
        .main_token = fn_token,
        .data = .{ .node_and_node = .{
            fn_proto, try renderNode(c, payload.body),
        } },
    });
}

fn renderParams(c: *Context, params: []Payload.Param, is_var_args: bool) !std.ArrayList(NodeIndex) {
    _ = try c.addToken(.l_paren, "(");
    var rendered = try std.ArrayList(NodeIndex).initCapacity(c.gpa, @max(params.len, 1));
    errdefer rendered.deinit();

    for (params, 0..) |param, i| {
        if (i != 0) _ = try c.addToken(.comma, ",");
        if (param.is_noalias) _ = try c.addToken(.keyword_noalias, "noalias");
        if (param.name) |some| {
            _ = try c.addIdentifier(some);
            _ = try c.addToken(.colon, ":");
        }
        if (param.type.tag() == .@"anytype") {
            _ = try c.addToken(.keyword_anytype, "anytype");
            continue;
        }
        rendered.appendAssumeCapacity(try renderNode(c, param.type));
    }
    if (is_var_args) {
        if (params.len != 0) _ = try c.addToken(.comma, ",");
        _ = try c.addToken(.ellipsis3, "...");
    }
    _ = try c.addToken(.r_paren, ")");

    return rendered;
}
