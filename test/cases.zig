const std = @import("std");
const TranslateC = @import("../build/TranslateC.zig");

pub fn addCaseTests(
    b: *std.Build,
    tests_step: *std.Build.Step,
    translate_exes: []const *std.Build.Step.Compile,
    target: std.Build.ResolvedTarget,
    skip_translate: bool,
    skip_run_translated: bool,
) !void {
    const test_translate_step = b.step("test-translate", "Run the C translation tests");
    if (!skip_translate) tests_step.dependOn(test_translate_step);

    const test_run_translated_step = b.step("test-run-translated", "Run the Run-Translated-C tests");
    if (!skip_run_translated) tests_step.dependOn(test_run_translated_step);

    var dir = try b.build_root.handle.openDir("test/cases", .{ .iterate = true });
    defer dir.close();

    var it = try dir.walk(b.allocator);
    while (try it.next()) |entry| {
        if (entry.kind != .file) continue;
        const case = caseFromFile(b, entry, target.query) catch |err|
            std.debug.panic("failed to process case '{s}': {s}", .{ entry.path, @errorName(err) });

        // Skip cases we expect to fail, would be nice to be able to check that they actually do fail.
        if (case.expect == .fail) continue;

        for (translate_exes) |exe| switch (case.kind) {
            .translate => |output| {
                const annotated_case_name = b.fmt("translate {s}", .{case.name});

                const write_src = b.addWriteFiles();
                const file_source = write_src.add("tmp.c", case.input);

                const translate_c = TranslateC.create(b, .{
                    .root_source_file = file_source,
                    .optimize = .Debug,
                    .target = case.target,
                    .translate_c_exe = exe,
                });
                translate_c.step.name = b.fmt("{s} TranslateC", .{annotated_case_name});

                const check_file = translate_c.addCheckFile(output);
                check_file.step.name = b.fmt("{s} CheckFile", .{annotated_case_name});
                test_translate_step.dependOn(&check_file.step);
            },
            .run => |output| {
                const annotated_case_name = b.fmt("run-translated {s}", .{case.name});

                const write_src = b.addWriteFiles();
                const file_source = write_src.add("tmp.c", case.input);

                const translate_c = TranslateC.create(b, .{
                    .root_source_file = file_source,
                    .optimize = .Debug,
                    .target = case.target,
                    .translate_c_exe = exe,
                });
                translate_c.step.name = b.fmt("{s} TranslateC", .{annotated_case_name});

                const run_exe = translate_c.addExecutable(.{});
                run_exe.step.name = b.fmt("{s} build-exe", .{annotated_case_name});
                run_exe.linkLibC();
                const run = b.addRunArtifact(run_exe);
                run.step.name = b.fmt("{s} run", .{annotated_case_name});
                run.expectStdOutEqual(output);
                run.skip_foreign_checks = true;

                test_run_translated_step.dependOn(&run.step);
            },
        };
    }
}

const Case = struct {
    name: []const u8,
    target: std.Build.ResolvedTarget,
    input: []const u8,
    expect: Expect,
    kind: Kind,

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

fn caseFromFile(b: *std.Build, entry: std.fs.Dir.Walker.Entry, default_target: std.Target.Query) !Case {
    const max_file_size = 10 * 1024 * 1024;
    const src = try entry.dir.readFileAlloc(b.allocator, entry.basename, max_file_size);

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

    var target = default_target;
    var expect: Case.Expect = .pass;

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
            target = try std.Target.Query.parse(.{ .arch_os_abi = value });
        } else if (std.mem.eql(u8, key, "expect")) {
            expect = std.meta.stringToEnum(Case.Expect, value) orelse return error.InvalidExpectValue;
        } else return error.InvalidTestConfigOption;
    }

    return .{
        .name = std.fs.path.stem(entry.basename),
        .target = b.resolveTargetQuery(target),
        .input = input,
        .expect = expect,
        .kind = switch (kind) {
            .run => .{ .run = try trailing(b.allocator, &it) },
            .translate => .{ .translate = try trailingSplit(b.allocator, &it) },
        },
    };
}

fn trailing(arena: std.mem.Allocator, it: *std.mem.TokenIterator(u8, .scalar)) ![]const u8 {
    var buf: std.ArrayList(u8) = .init(arena);
    defer buf.deinit();
    while (it.next()) |line| {
        if (line.len < 3) continue;
        const trimmed = line[3..];
        if (buf.items.len != 0) try buf.append('\n');
        try buf.appendSlice(trimmed);
    }
    return try buf.toOwnedSlice();
}

fn trailingSplit(arena: std.mem.Allocator, it: *std.mem.TokenIterator(u8, .scalar)) ![]const []const u8 {
    var out: std.ArrayList([]const u8) = .init(arena);
    defer out.deinit();
    var buf: std.ArrayList(u8) = .init(arena);
    defer buf.deinit();

    while (it.next()) |line| {
        if (line.len < 3) continue;
        const trimmed = line[3..];
        if (trimmed.len == 0) {
            if (buf.items.len != 0) {
                try out.append(try buf.toOwnedSlice());
            }
            continue;
        }
        if (buf.items.len != 0) try buf.append('\n');
        try buf.appendSlice(trimmed);
    }
    if (buf.items.len != 0) {
        try out.append(try buf.toOwnedSlice());
    }
    return try out.toOwnedSlice();
}
