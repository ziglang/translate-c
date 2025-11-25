const std = @import("std");

/// Import the `Translator` helper from the `translate_c` dependency.
const Translator = @import("translate_c").Translator;

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Prepare the `translate-c` dependency.
    const translate_c = b.dependency("translate_c", .{});

    // Create a step to translate Python.h directly. This also creates a Zig module from the output.
    const python_h: Translator = .init(translate_c, .{
        .c_source_file = .{ .cwd_relative = "/home/jacobz/miniforge3/include/python3.12/Python.h" },
        .target = target,
        .optimize = optimize,
    });

    // Add Python include paths for resolving dependencies
    python_h.addIncludePath(.{ .cwd_relative = "/home/jacobz/miniforge3/include/python3.12" });

    // Create a module for our Python extension
    const extension_module = b.createModule(.{
        .root_source_file = b.path("extension.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .imports = &.{
            // Add the translated header module as an import for the extension module.
            .{
                .name = "python",
                .module = python_h.mod,
            },
        },
    });

    // Build the shared library (Python extension) - use b.addLibrary with dynamic linkage
    const extension_lib = b.addLibrary(.{
        .name = "zig_ext",
        .root_module = extension_module,
        .linkage = .dynamic, // This creates a shared library (.so)
    });

    // Allow undefined symbols for Python dynamic linking
    extension_lib.linker_allow_shlib_undefined = true;

    // Install the shared library
    b.installArtifact(extension_lib);

    // Create build step
    const build_step = b.step("build", "Build the Python extension");
    build_step.dependOn(&extension_lib.step);

    // Create test step
    const test_step = b.step("test", "Test the Python extension by importing and using it");
    test_step.dependOn(&extension_lib.step);

    // Add a Python script to test the extension
    const test_python = b.addSystemCommand(&.{
        "python3", "-c",
        \\import sys;
        \\import os;
        \\# Add the zig-out/lib directory to Python path
        \\sys.path.insert(0, 'zig-out/lib');
        \\try:
        \\    import zig_ext;
        \\    print("Successfully imported Python extension 'zig_ext'!")
        \\    print("Testing zig_ext.get_greeting():");
        \\    greeting = zig_ext.get_greeting();
        \\    print(greeting)
        \\    print("Testing zig_ext.add_numbers(10, 20):");
        \\    result = zig_ext.add_numbers(10, 20);
        \\    print(f"zig_ext.add_numbers(10, 20) = {result}")
        \\    print("✅ All tests passed!")
        \\except Exception as e:
        \\    print(f"❌ Error: {e}");
        \\    import traceback;
        \\    traceback.print_exc();
        \\    sys.exit(1)
    });

    test_step.dependOn(&test_python.step);

    // Set default step to build
    b.default_step = build_step;
}
