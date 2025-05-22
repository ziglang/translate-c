const std = @import("std");
const assert = std.debug.assert;
const mem = std.mem;
const process = std.process;
const aro = @import("aro");
const Translator = @import("Translator.zig");

const fast_exit = @import("builtin").mode != .Debug;

var general_purpose_allocator: std.heap.GeneralPurposeAllocator(.{}) = .init;

pub fn main() u8 {
    const gpa = general_purpose_allocator.allocator();
    defer _ = general_purpose_allocator.deinit();

    var arena_instance = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();

    const args = process.argsAlloc(arena) catch {
        std.debug.print("ran out of memory allocating arguments\n", .{});
        if (fast_exit) process.exit(1);
        return 1;
    };

    const stderr = std.io.getStdErr();
    var diagnostics: aro.Diagnostics = .{
        .output = .{ .to_file = .{
            .file = stderr,
            .config = std.io.tty.detectConfig(stderr),
        } },
    };

    var comp = aro.Compilation.initDefault(gpa, &diagnostics, std.fs.cwd()) catch |err| switch (err) {
        error.OutOfMemory => {
            std.debug.print("ran out of memory initializing C compilation\n", .{});
            if (fast_exit) process.exit(1);
            return 1;
        },
    };
    defer comp.deinit();

    const exe_name = std.fs.selfExePathAlloc(gpa) catch {
        std.debug.print("unable to find translate-c executable path\n", .{});
        if (fast_exit) process.exit(1);
        return 1;
    };
    defer gpa.free(exe_name);

    var driver: aro.Driver = .{ .comp = &comp, .diagnostics = &diagnostics, .aro_name = exe_name };
    defer driver.deinit();

    var toolchain: aro.Toolchain = .{ .driver = &driver, .arena = arena, .filesystem = .{ .real = comp.cwd } };
    defer toolchain.deinit();

    translate(&driver, &toolchain, args) catch |err| switch (err) {
        error.OutOfMemory => {
            std.debug.print("ran out of memory translating\n", .{});
            if (fast_exit) process.exit(1);
            return 1;
        },
        error.FatalError => {
            if (fast_exit) process.exit(1);
            return 1;
        },
    };
    if (fast_exit) process.exit(@intFromBool(comp.diagnostics.errors != 0));
    return @intFromBool(comp.diagnostics.errors != 0);
}

pub const usage =
    \\Usage {s}: [options] file [CC options]
    \\
    \\General options:
    \\  -h, --help      Print this message.
    \\  -v, --version   Print translate-c version.
    \\
    \\
;

fn translate(d: *aro.Driver, tc: *aro.Toolchain, args: [][:0]u8) !void {
    const gpa = d.comp.gpa;

    var macro_buf = std.ArrayList(u8).init(gpa);
    defer macro_buf.deinit();

    try macro_buf.appendSlice("#define __TRANSLATE_C__ 1\n");

    const aro_args = args: {
        var i: usize = 0;
        for (args) |arg| {
            args[i] = arg;
            if (mem.eql(u8, arg, "-h") or mem.eql(u8, arg, "--help")) {
                const stdout = std.io.getStdOut();
                stdout.writer().print(usage, .{args[0]}) catch |er| {
                    return d.fatal("unable to print usage: {s}", .{aro.Driver.errorDescription(er)});
                };
                return;
            } else if (mem.eql(u8, arg, "-v") or mem.eql(u8, arg, "--version")) {
                const stdout = std.io.getStdOut();
                // TODO add version
                stdout.writeAll("0.0.0-dev\n") catch |er| {
                    return d.fatal("unable to print version: {s}", .{aro.Driver.errorDescription(er)});
                };
                return;
            } else {
                i += 1;
            }
        }
        break :args args[0..i];
    };
    assert(!try d.parseArgs(std.io.null_writer, macro_buf.writer(), aro_args));

    if (d.inputs.items.len != 1) {
        return d.fatal("expected exactly one input file", .{});
    }
    const source = d.inputs.items[0];

    tc.discover() catch |er| switch (er) {
        error.OutOfMemory => return error.OutOfMemory,
        error.TooManyMultilibs => return d.fatal("found more than one multilib with the same priority", .{}),
    };
    tc.defineSystemIncludes() catch |er| switch (er) {
        error.OutOfMemory => return error.OutOfMemory,
        error.AroIncludeNotFound => return d.fatal("unable to find Aro builtin headers", .{}),
    };

    const builtin_macros = d.comp.generateBuiltinMacros(.include_system_defines) catch |err| switch (err) {
        error.StreamTooLong => return d.fatal("builtin macro source exceeded max size", .{}),
        else => |e| return e,
    };
    const user_macros = d.comp.addSourceFromBuffer("<command line>", macro_buf.items) catch |err| switch (err) {
        error.StreamTooLong => return d.fatal("user provided macro source exceeded max size", .{}),
        else => |e| return e,
    };

    var pp = try aro.Preprocessor.initDefault(d.comp);
    defer pp.deinit();

    try pp.preprocessSources(&.{ source, builtin_macros, user_macros });

    var c_tree = try pp.parse();
    defer c_tree.deinit();

    if (d.diagnostics.errors != 0) {
        if (fast_exit) process.exit(1);
        return error.FatalError;
    }

    const rendered_zig = try Translator.translate(gpa, d.comp, &pp, &c_tree);
    defer gpa.free(rendered_zig);

    var close_out_file = false;
    var out_file_path: []const u8 = "<stdout>";
    var out_file = std.io.getStdOut();
    defer if (close_out_file) out_file.close();

    if (d.output_name) |path| blk: {
        if (std.mem.eql(u8, path, "-")) break :blk;
        out_file = std.fs.cwd().createFile(path, .{}) catch |err| {
            return d.fatal("failed to create output file '{s}': {s}", .{ path, aro.Driver.errorDescription(err) });
        };
        close_out_file = true;
        out_file_path = path;
    }
    out_file.writeAll(rendered_zig) catch |err|
        return d.fatal("failed to write result to '{s}': {s}", .{ out_file_path, aro.Driver.errorDescription(err) });

    if (fast_exit) process.exit(0);
}

comptime {
    if (@import("builtin").is_test) {
        _ = Translator;
        _ = @import("helpers.zig");
        _ = @import("PatternList.zig");
    }
}
