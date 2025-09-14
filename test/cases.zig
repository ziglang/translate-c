const std = @import("std");
const Translator = @import("../build/Translator.zig");

const cross_targets: []const []const u8 = &.{
    "x86_64-linux",
    "x86_64-windows",
    "aarch64-linux",
    "aarch64-macos",
    "arm-linux",
};

pub fn lowerCases(
    b: *std.Build,
    translator_conf: Translator.TranslateCConfig,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    test_cross_targets: bool,
    test_translate_step: *std.Build.Step,
    test_run_translated_step: *std.Build.Step,
) void {
    var targets_buf: [cross_targets.len + 1]std.Build.ResolvedTarget = undefined;
    const targets: []const std.Build.ResolvedTarget = targets: {
        targets_buf[0] = target;
        if (!test_cross_targets) break :targets targets_buf[0..1];
        for (cross_targets, targets_buf[1..]) |query_str, *resolved| {
            const query = std.Target.Query.parse(.{ .arch_os_abi = query_str }) catch unreachable;
            resolved.* = b.resolveTargetQuery(query);
        }
        break :targets &targets_buf;
    };

    var dir = b.build_root.handle.openDir("test/cases", .{ .iterate = true }) catch |err| {
        const fail_step = b.addFail(b.fmt("unable to open test/cases: {s}", .{@errorName(err)}));
        test_translate_step.dependOn(&fail_step.step);
        test_run_translated_step.dependOn(&fail_step.step);
        return;
    };
    defer dir.close();

    var it = dir.walk(b.allocator) catch |err| std.debug.panic("failed to walk cases: {s}", .{@errorName(err)});
    while (it.next() catch |err| {
        std.debug.panic("failed to walk cases: {s}", .{@errorName(err)});
    }) |entry| {
        if (entry.kind != .file) continue;
        const case = caseFromFile(b, entry) catch |err|
            std.debug.panic("failed to process case '{s}': {s}", .{ entry.path, @errorName(err) });

        const source_file = b.addWriteFiles().add("tmp.c", case.input);

        const case_targets = if (case.target) |*t| t[0..1] else targets;
        for (case_targets) |case_target| {
            if (case.skip_windows and case_target.result.os.tag == .windows) {
                continue;
            }
            const name_and_triple = b.fmt("{s} {s}", .{
                case_target.query.zigTriple(b.graph.arena) catch @panic("OOM"),
                case.name,
            });
            const translator: Translator = .initInner(b, translator_conf, .{
                .name = name_and_triple,
                .c_source_file = source_file,
                .target = case_target,
                .optimize = optimize,
            });
            switch (case.kind) {
                .translate => |output| {
                    const check_file = b.addCheckFile(translator.output_file, .{ .expected_matches = output });
                    check_file.step.name = b.fmt("check-translated {s}", .{name_and_triple});
                    test_translate_step.dependOn(&check_file.step);
                },
                .run => |output| {
                    const exe = b.addExecutable(.{ .name = case.name, .root_module = translator.mod });
                    const run = b.addRunArtifact(exe);
                    run.step.name = b.fmt("run-translated {s}", .{name_and_triple});
                    run.expectStdOutEqual(output);
                    run.skip_foreign_checks = true;
                    test_run_translated_step.dependOn(&run.step);
                },
            }
        }
    }
}

const Case = struct {
    name: []const u8,
    /// This is an override; usually `null`.
    target: ?std.Build.ResolvedTarget,
    input: []const u8,
    kind: Kind,
    skip_windows: bool,

    const Expect = enum { pass, fail };

    const Kind = union(enum) {
        /// Translate the input, run it and check that it
        /// outputs the expected text.
        run: []const u8,
        /// Translate the input and check that it contains
        /// the expected lines of code.
        translate: []const []const u8,
    };
};

fn caseFromFile(b: *std.Build, entry: std.fs.Dir.Walker.Entry) !Case {
    const max_file_size = 10 * 1024 * 1024;
    const src = try entry.dir.readFileAlloc(entry.basename, b.allocator, .limited(max_file_size));

    const input, const manifest = blk: {
        var start: ?usize = null;
        const bytes = std.mem.trimRight(u8, src, " \t\n");
        var cursor = bytes.len;
        while (true) : (cursor -= 1) {
            while (cursor > 0 and bytes[cursor - 1] != '\n') cursor -= 1;

            if (std.mem.startsWith(u8, bytes[cursor..], "//")) {
                start = cursor;
            } else break;
        }
        const manifest_start = start orelse return error.TestManifestMissing;
        break :blk .{ bytes[0..manifest_start], bytes[manifest_start..] };
    };

    var target: ?std.Target.Query = null;
    var skip_windows = true;

    var it = std.mem.tokenizeScalar(u8, manifest, '\n');

    const kind = kind: {
        const line = it.next() orelse return error.TestManifestMissingType;
        const trimmed = std.mem.trim(u8, line[2..], " \t");
        break :kind std.meta.stringToEnum(std.meta.Tag(Case.Kind), trimmed) orelse {
            std.log.warn("invalid test case type: {s}", .{trimmed});
            return error.TestManifestInvalidType;
        };
    };

    while (it.next()) |line| {
        const trimmed = std.mem.trim(u8, line[2..], " \t");

        if (trimmed.len == 0) break; // Start of trailing data.

        var kv_it = std.mem.splitScalar(u8, trimmed, '=');
        const key = kv_it.first();
        const value = kv_it.next() orelse return error.MissingValuesForConfig;
        if (std.mem.eql(u8, key, "target")) {
            target = try .parse(.{ .arch_os_abi = value });
        } else if (std.mem.eql(u8, key, "skip_windows")) {
            skip_windows = std.mem.eql(u8, value, "true");
        } else return error.InvalidTestConfigOption;
    }

    return .{
        .name = std.fs.path.stem(entry.basename),
        .target = if (target) |q| b.resolveTargetQuery(q) else null,
        .input = input,
        .kind = switch (kind) {
            .run => .{ .run = try trailing(b.allocator, &it) },
            .translate => .{ .translate = try trailingSplit(b.allocator, &it) },
        },
        .skip_windows = skip_windows,
    };
}

fn trailing(arena: std.mem.Allocator, it: *std.mem.TokenIterator(u8, .scalar)) ![]const u8 {
    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(arena);
    while (it.next()) |line| {
        if (line.len < 3) continue;
        const trimmed = line[3..];
        if (buf.items.len != 0) try buf.append(arena, '\n');
        try buf.appendSlice(arena, trimmed);
    }
    return try buf.toOwnedSlice(arena);
}

fn trailingSplit(arena: std.mem.Allocator, it: *std.mem.TokenIterator(u8, .scalar)) ![]const []const u8 {
    var out: std.ArrayList([]const u8) = .empty;
    defer out.deinit(arena);
    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(arena);

    while (it.next()) |line| {
        if (line.len <= 3) {
            if (buf.items.len != 0) {
                try out.append(arena, try buf.toOwnedSlice(arena));
            }
            continue;
        }
        const trimmed = line[3..];
        if (buf.items.len != 0) try buf.append(arena, '\n');
        try buf.appendSlice(arena, trimmed);
    }
    if (buf.items.len != 0) {
        try out.append(arena, try buf.toOwnedSlice(arena));
    }
    return try out.toOwnedSlice(arena);
}
