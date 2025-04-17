const std = @import("std");

/// Import the `TranslateC` step from the `translate_c` dependency.
const TranslateC = @import("translate_c").TranslateC;

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create a step to translate `header.h`.
    const translate_step = TranslateC.create(b, .{
        .root_source_file = b.path("header.h"),
        .target = target,
        .optimize = optimize,
    });

    // Create a Zig module from the result.
    const header_module = translate_step.createModule();

    const main_module = b.createModule(.{
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            // Add the translated module as an import for the main module.
            .{
                .name = "header",
                .module = header_module,
            },
        },
    });

    const unit_tests = b.addTest(.{
        .root_module = main_module,
    });
    b.default_step.dependOn(&unit_tests.step);
}
