const std = @import("std");

/// Import the `TranslateC` step from the `translate_c` dependency.
const TranslateC = @import("translate_c").TranslateC;

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create a step to translate `main.c`.
    const translate_step = TranslateC.create(b, .{
        .root_source_file = b.path("main.c"),
        .target = target,
        .optimize = optimize,
    });

    // Create a Zig module from the result.
    const main_module = translate_step.createModule();

    const translated_exe = b.addExecutable(.{
        .name = "translated-exe",
        .root_module = main_module,
    });

    const run_translated_cmd = b.addRunArtifact(translated_exe);
    const run_translated_step = b.step("run-translated", "Run the exe translated to Zig");
    run_translated_step.dependOn(&run_translated_cmd.step);
    b.default_step.dependOn(run_translated_step);

    // Same as above but without translating to Zig first.
    const c_module = b.createModule(.{
        .link_libc = true,
        .target = target,
        .optimize = optimize,
    });
    c_module.addCSourceFile(.{ .file = b.path("main.c") });

    const c_exe = b.addExecutable(.{
        .name = "c-exe",
        .root_module = c_module,
    });

    const run_c_cmd = b.addRunArtifact(c_exe);
    const run_c_step = b.step("run-c", "Run the C exe");
    run_c_step.dependOn(&run_c_cmd.step);
    b.default_step.dependOn(run_c_step);
}
