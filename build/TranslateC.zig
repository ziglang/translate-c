const std = @import("std");
const Step = std.Build.Step;
const LazyPath = std.Build.LazyPath;
const fs = std.fs;
const mem = std.mem;

const TranslateC = @This();

pub const base_id: Step.Id = .custom;

step: Step,
translate_c_exe: *Step.Compile,
source: std.Build.LazyPath,
include_dirs: std.ArrayList(std.Build.Module.IncludeDir),
target: std.Build.ResolvedTarget,
optimize: std.builtin.OptimizeMode,
output_file: std.Build.GeneratedFile,
link_libc: bool,

pub const Options = struct {
    root_source_file: std.Build.LazyPath,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    link_libc: bool = true,
    translate_c_dep_name: []const u8 = "translate-c",
};

pub fn create(owner: *std.Build, options: Options) *TranslateC {
    const translate_c_exe = owner.dependency(options.translate_c_dep_name, .{
        .optimize = .ReleaseFast,
    }).artifact("translate-c");

    const translate_c = owner.allocator.create(TranslateC) catch @panic("OOM");
    const source = options.root_source_file.dupe(owner);
    translate_c.* = .{
        .step = Step.init(.{
            .id = base_id,
            .name = "translate-c",
            .owner = owner,
            .makeFn = make,
        }),
        .translate_c_exe = translate_c_exe,
        .source = source,
        .include_dirs = .init(owner.allocator),
        .target = options.target,
        .optimize = options.optimize,
        .output_file = .{ .step = &translate_c.step },
        .link_libc = options.link_libc,
    };
    source.addStepDependencies(&translate_c.step);
    translate_c.step.dependOn(&translate_c_exe.step);
    return translate_c;
}

pub const AddExecutableOptions = struct {
    name: ?[]const u8 = null,
    version: ?std.SemanticVersion = null,
    target: ?std.Build.ResolvedTarget = null,
    optimize: ?std.builtin.OptimizeMode = null,
    linkage: ?std.builtin.LinkMode = null,
};

pub fn getOutput(translate_c: *TranslateC) std.Build.LazyPath {
    return .{ .generated = .{ .file = &translate_c.output_file } };
}

/// Creates a step to build an executable from the translated source.
pub fn addExecutable(translate_c: *TranslateC, options: AddExecutableOptions) *Step.Compile {
    return translate_c.step.owner.addExecutable(.{
        .root_source_file = translate_c.getOutput(),
        .name = options.name orelse "translated_c",
        .version = options.version,
        .target = options.target orelse translate_c.target,
        .optimize = options.optimize orelse translate_c.optimize,
        .linkage = options.linkage,
    });
}

/// Creates a module from the translated source and adds it to the package's
/// module set making it available to other packages which depend on this one.
/// `createModule` can be used instead to create a private module.
pub fn addModule(translate_c: *TranslateC, name: []const u8) *std.Build.Module {
    return translate_c.step.owner.addModule(name, .{
        .root_source_file = translate_c.getOutput(),
    });
}

/// Creates a private module from the translated source to be used by the
/// current package, but not exposed to other packages depending on this one.
/// `addModule` can be used instead to create a public module.
pub fn createModule(translate_c: *TranslateC) *std.Build.Module {
    return translate_c.step.owner.createModule(.{
        .root_source_file = translate_c.getOutput(),
        .target = translate_c.target,
        .optimize = translate_c.optimize,
        .link_libc = translate_c.link_libc,
    });
}

pub fn addCheckFile(translate_c: *TranslateC, expected_matches: []const []const u8) *Step.CheckFile {
    return Step.CheckFile.create(
        translate_c.step.owner,
        translate_c.getOutput(),
        .{ .expected_matches = expected_matches },
    );
}

fn make(step: *Step, options: Step.MakeOptions) !void {
    _ = options;
    const translate_c: *TranslateC = @fieldParentPtr("step", step);
    _ = translate_c;
}
