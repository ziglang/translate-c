const std = @import("std");

pub const TranslateC = @import("build/TranslateC.zig");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const aro = b.dependency("aro", .{
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "translate-c",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("aro", aro.module("aro"));
    b.installDirectory(.{
        .source_dir = aro.path("include"),
        .install_dir = .prefix,
        .install_subdir = "include",
    });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run translate-c");
    run_step.dependOn(&run_cmd.step);

    const skip_debug = b.option(bool, "skip-debug", "Main test suite skips debug builds") orelse false;
    const skip_release = b.option(bool, "skip-release", "Main test suite skips release builds") orelse false;
    const skip_release_small = b.option(bool, "skip-release-small", "Main test suite skips release-small builds") orelse skip_release;
    const skip_release_fast = b.option(bool, "skip-release-fast", "Main test suite skips release-fast builds") orelse skip_release;
    const skip_release_safe = b.option(bool, "skip-release-safe", "Main test suite skips release-safe builds") orelse skip_release;
    const skip_translate = b.option(bool, "skip-translate", "Main test suite skips translate tests") orelse false;
    const skip_run_translated = b.option(bool, "skip-run-translated", "Main test suite skips run-translated tests") orelse false;

    const optimization_modes: []const std.builtin.OptimizeMode = modes: {
        var chosen_opt_modes_buf: [4]std.builtin.OptimizeMode = undefined;
        var chosen_mode_index: usize = 0;
        if (!skip_debug) {
            chosen_opt_modes_buf[chosen_mode_index] = .Debug;
            chosen_mode_index += 1;
        }
        if (!skip_release_safe) {
            chosen_opt_modes_buf[chosen_mode_index] = .ReleaseSafe;
            chosen_mode_index += 1;
        }
        if (!skip_release_fast) {
            chosen_opt_modes_buf[chosen_mode_index] = .ReleaseFast;
            chosen_mode_index += 1;
        }
        if (!skip_release_small) {
            chosen_opt_modes_buf[chosen_mode_index] = .ReleaseSmall;
            chosen_mode_index += 1;
        }
        break :modes chosen_opt_modes_buf[0..chosen_mode_index];
    };

    const test_step = b.step("test", "Run all tests");

    const fmt_dirs: []const []const u8 = &.{ "build", "src", "test" };
    b.step("fmt", "Modify source files in place to have conforming formatting")
        .dependOn(&b.addFmt(.{ .paths = fmt_dirs }).step);

    const test_fmt = b.step("test-fmt", "Check source files having conforming formatting");
    test_fmt.dependOn(&b.addFmt(.{ .paths = fmt_dirs, .check = true }).step);
    test_step.dependOn(test_fmt);

    {
        const unit_test_step = b.step("test-unit", "Run unit tests");
        for (optimization_modes) |mode| {
            const unit_tests = b.addTest(.{
                .root_source_file = b.path("src/Translator.zig"),
                .target = target,
                .optimize = mode,
            });
            unit_tests.root_module.addImport("aro", aro.module("aro"));
            const run_unit_tests = b.addRunArtifact(unit_tests);
            unit_test_step.dependOn(&run_unit_tests.step);
        }
        test_step.dependOn(unit_test_step);
    }

    try @import("test/cases.zig").addCaseTests(
        b,
        test_step,
        optimization_modes,
        target,
        skip_translate,
        skip_run_translated,
    );
}
