const std = @import("std");

/// Import the `Translator` helper from the `translate_c` dependency.
const Translator = @import("translate_c").Translator;

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Prepare the `translate-c` dependency.
    const translate_c = b.dependency("translate_c", .{});

    // Create a step to translate `header.h`. This also creates a Zig module from the output.
    const header: Translator = .init(translate_c, .{
        .c_source_file = b.path("header.h"),
        .target = target,
        .optimize = optimize,
    });

    // Now we'll compile a test which depends on the translated header.
    // To do that, we must create a module for the actual test.
    const test_module = b.createModule(.{
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            // Add the translated header module as an import for the test module.
            .{
                .name = "header",
                .module = header.mod,
            },
        },
    });

    // Lastly, build and run that test.

    const test_step = b.step("test", "Build and run the test");
    b.default_step = test_step;

    const test_exe = b.addTest(.{ .root_module = test_module });
    const run_test = b.addRunArtifact(test_exe);
    test_step.dependOn(&run_test.step);
}
