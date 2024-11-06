const std = @import("std");
const assert = std.debug.assert;
const aro = @import("aro");
const Translator = @import("Translator.zig");

// TODO cleanup and handle errors more gracefully
pub fn main() !void {
    var arena_instance = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();

    var general_purpose_allocator: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const gpa = general_purpose_allocator.allocator();

    const args = try std.process.argsAlloc(arena);

    var comp = aro.Compilation.init(gpa, std.fs.cwd());
    defer comp.deinit();

    try comp.addDefaultPragmaHandlers();
    comp.langopts.setEmulatedCompiler(aro.target_util.systemCompiler(comp.target));

    var driver: aro.Driver = .{ .comp = &comp };
    defer driver.deinit();

    var macro_buf = std.ArrayList(u8).init(gpa);
    defer macro_buf.deinit();

    assert(!try driver.parseArgs(std.io.null_writer, macro_buf.writer(), args));
    assert(driver.inputs.items.len == 1);
    const source = driver.inputs.items[0];

    const builtin_macros = try comp.generateBuiltinMacros(.include_system_defines, null);
    const user_macros = try comp.addSourceFromBuffer("<command line>", macro_buf.items);

    var pp = try aro.Preprocessor.initDefault(&comp);
    defer pp.deinit();

    try pp.preprocessSources(&.{ source, builtin_macros, user_macros });

    var c_tree = try pp.parse();
    defer c_tree.deinit();

    // Workaround for https://github.com/Vexu/arocc/issues/603
    for (comp.diagnostics.list.items) |msg| {
        if (msg.kind == .@"error" or msg.kind == .@"fatal error") return renderErrorsAndExit(&comp);
    }

    var zig_tree = try Translator.translate(gpa, &comp, c_tree);
    defer zig_tree.deinit(gpa);

    const formatted = try zig_tree.render(arena);
    if (driver.output_name) |path| blk: {
        if (std.mem.eql(u8, path, "-")) break :blk;
        const out_file = try std.fs.cwd().createFile(path, .{});
        defer out_file.close();

        try out_file.writeAll(formatted);
        return std.process.cleanExit();
    }
    try std.io.getStdOut().writeAll(formatted);
    return std.process.cleanExit();
}

/// Renders errors and fatal errors + associated notes (e.g. "expanded from here"); does not render warnings or associated notes
/// Terminates with exit code 1
fn renderErrorsAndExit(comp: *aro.Compilation) noreturn {
    defer std.process.exit(1);

    var writer = aro.Diagnostics.defaultMsgWriter(std.io.tty.detectConfig(std.io.getStdErr()));
    defer writer.deinit(); // writer deinit must run *before* exit so that stderr is flushed

    var saw_error = false;
    for (comp.diagnostics.list.items) |msg| {
        switch (msg.kind) {
            .@"error", .@"fatal error" => {
                saw_error = true;
                aro.Diagnostics.renderMessage(comp, &writer, msg);
            },
            .warning => saw_error = false,
            .note => {
                if (saw_error) {
                    aro.Diagnostics.renderMessage(comp, &writer, msg);
                }
            },
            .off => {},
            .default => unreachable,
        }
    }
}
