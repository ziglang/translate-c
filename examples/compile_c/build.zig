const std = @import("std");

/// Import the `Translator` helper from the `translate_c` dependency.
const Translator = @import("translate_c").Translator;

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Prepare the `translate-c` dependency.
    const translate_c = b.dependency("translate_c", .{});

    // Create a step to translate `main.c`. This also creates a Zig module from the output.
    const trans: Translator = .init(translate_c, .{
        .c_source_file = b.path("main.c"),
        .target = target,
        .optimize = optimize,
    });
    // Build an executable from `trans.mod` (the Zig module containing the translated code).
    const translated_exe = b.addExecutable(.{
        .name = "translated-exe",
        .root_module = trans.mod,
    });

    // Like above, but compile the C code directly instead of using `translate-c`.
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

    // We have two executables. Run them both, and test that they do what we expect.

    const test_step = b.step("test", "Build and test both executables");
    b.default_step = test_step;

    const test_c = b.addRunArtifact(c_exe);
    test_c.expectStdOutEqual("Hello from my C program!\n");
    test_step.dependOn(&test_c.step);

    const test_translated = b.addRunArtifact(translated_exe);
    test_translated.expectStdOutEqual("Hello from my Zig program!\n");
    test_step.dependOn(&test_translated.step);

    // These are just steps you can use to actually see the output of each executable.
    b.step("run-translated", "Run the translated Zig executable")
        .dependOn(&b.addRunArtifact(translated_exe).step);
    b.step("run-c", "Run the directly compiled C executable")
        .dependOn(&b.addRunArtifact(c_exe).step);
}
