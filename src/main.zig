const std = @import("std");
const aro = @import("aro");
const Translator = @import("Translator.zig");

pub fn main() !void {
    var arena_instance = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();

    var general_purpose_allocator: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const gpa = general_purpose_allocator.allocator();

    const args = try std.process.argsAlloc(arena);

    var aro_comp = aro.Compilation.init(gpa, std.fs.cwd());
    defer aro_comp.deinit();

    var tree = Translator.translate(gpa, &aro_comp, args) catch |err| switch (err) {
        error.ParsingFailed, error.FatalError => renderErrorsAndExit(&aro_comp),
        error.OutOfMemory => return error.OutOfMemory,
        error.StreamTooLong => std.zig.fatal("An input file was larger than 4GiB", .{}),
    };
    defer tree.deinit(gpa);

    const formatted = try tree.render(arena);
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
