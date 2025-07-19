const std = @import("std");

/// Import the `Translator` helper from the `translate_c` dependency.
const Translator = @import("translate_c").Translator;

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Prepare the `translate-c` dependency.
    const translate_c = b.dependency("translate_c", .{});

    // Build the C library. In reality this would probably be done via the package manager.
    const libfoo = buildLibfoo(b, target, optimize);

    // Create a `Translator` for C source code which `#include`s the needed headers.
    // If necessary, it could also include different headers, define macros, etc.
    const trans_libfoo: Translator = .init(translate_c, .{
        .c_source_file = b.addWriteFiles().add("c.h",
            \\#include <foo/add.h>
            \\#include <foo/print.h>
        ),
        .target = target,
        .optimize = optimize,
    });
    // Of course, we need to link against `libfoo`! This call tells `translate-c` where to
    // find the headers we included, but it also makes `trans_libfoo.mod` actually link the
    // library.
    trans_libfoo.linkLibrary(libfoo);

    // We've now exposed `libfoo` as a Zig module! We can set up a compilation for a normal
    // Zig executable, include the generated module `trans_libfoo.mod`, and everything will
    // work. Let's check that `main.zig` works as expected.

    const main_mod = b.createModule(.{
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });
    main_mod.addImport("foo", trans_libfoo.mod);
    const main_exe = b.addExecutable(.{
        .name = "main",
        .root_module = main_mod,
    });

    const test_step = b.step("test", "Build and test the executable");
    b.default_step = test_step;

    // Windows libc changes stdout newlines to CRLF by default.
    const newline: []const u8 = if (target.result.os.tag == .windows) "\r\n" else "\n";

    const test_exe = b.addRunArtifact(main_exe);
    test_exe.expectStdOutEqual(b.fmt("1 + 2 = 3{s}", .{newline}));
    test_step.dependOn(&test_exe.step);

    const run_step = b.step("run", "Build and run the executable");
    const run_exe = b.addRunArtifact(main_exe);
    run_step.dependOn(&run_exe.step);
}

fn buildLibfoo(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step.Compile {
    const mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    mod.addCSourceFiles(.{
        .root = b.path("libfoo"),
        .files = &.{ "add.c", "print.c" },
    });
    const lib = b.addLibrary(.{
        .name = "foo",
        .root_module = mod,
    });
    // Install the headers, so that linking this library makes those headers available.
    lib.installHeader(b.path("libfoo/add.h"), "foo/add.h");
    lib.installHeader(b.path("libfoo/print.h"), "foo/print.h");
    return lib;
}
