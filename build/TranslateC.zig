const std = @import("std");
const Step = std.Build.Step;
const LazyPath = std.Build.LazyPath;
const fs = std.fs;
const mem = std.mem;

const TranslateC = @This();

pub const base_id: Step.Id = .custom;

step: Step,
translate_c_exe: *Step.Compile,
builtins_module: *std.Build.Module,
helpers_module: *std.Build.Module,
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
    translate_c_exe: ?*std.Build.Step.Compile = null,
    builtins_module: ?*std.Build.Module = null,
    helpers_module: ?*std.Build.Module = null,
    translate_c_dep_name: []const u8 = "translate-c",
    translate_c_optimize: std.builtin.OptimizeMode = .ReleaseFast,
};

pub fn create(owner: *std.Build, options: Options) *TranslateC {
    const translate_c_exe = options.translate_c_exe orelse owner.dependency(options.translate_c_dep_name, .{
        .optimize = options.translate_c_optimize,
    }).artifact("translate-c");
    const builtins_module = options.builtins_module orelse owner.dependency(options.translate_c_dep_name, .{
        .optimize = options.translate_c_optimize,
    }).module("builtins");
    const helpers_module = options.helpers_module orelse owner.dependency(options.translate_c_dep_name, .{
        .optimize = options.translate_c_optimize,
    }).module("helpers");

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
        .builtins_module = builtins_module,
        .helpers_module = helpers_module,
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
        .root_module = translate_c.createModule(),
        .name = options.name orelse "translated_c",
        .version = options.version,
        .linkage = options.linkage,
    });
}

/// Creates a module from the translated source and adds it to the package's
/// module set making it available to other packages which depend on this one.
/// `createModule` can be used instead to create a private module.
pub fn addModule(translate_c: *TranslateC, name: []const u8) *std.Build.Module {
    return translate_c.step.owner.addModule(name, .{
        .root_source_file = translate_c.getOutput(),
        .target = translate_c.target,
        .optimize = translate_c.optimize,
        .link_libc = translate_c.link_libc,
        .imports = &.{
            .{
                .name = "c_builtins",
                .module = translate_c.builtins_module,
            },
            .{
                .name = "helpers",
                .module = translate_c.helpers_module,
            },
        },
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
        .imports = &.{
            .{
                .name = "c_builtins",
                .module = translate_c.builtins_module,
            },
            .{
                .name = "helpers",
                .module = translate_c.helpers_module,
            },
        },
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
    const b = step.owner;
    const translate_c: *TranslateC = @fieldParentPtr("step", step);

    var argv_list = std.ArrayList([]const u8).init(b.allocator);
    const exe_path = translate_c.translate_c_exe.getEmittedBin().getPath(b);
    try argv_list.append(exe_path);

    var man = b.graph.cache.obtain();
    defer man.deinit();

    // Random bytes to make TranslateC outputs unique.
    man.hash.add(@as(u32, 0x2701BED2));
    man.hash.addBytes(exe_path);

    if (!translate_c.target.query.isNative()) {
        const triple = try translate_c.target.query.zigTriple(b.allocator);
        try argv_list.append(b.fmt("--target={s}", .{triple}));
        man.hash.addBytes(triple);
    }

    const c_source_path = translate_c.source.getPath3(b, step);
    _ = try man.addFilePath(c_source_path, null);
    const resolved_source_path = b.pathResolve(&.{ c_source_path.root_dir.path orelse ".", c_source_path.sub_path });
    try argv_list.append(resolved_source_path);

    const out_name = b.fmt("{s}.zig", .{std.fs.path.stem(c_source_path.sub_path)});
    if (try step.cacheHit(&man)) {
        const digest = man.final();
        translate_c.output_file.path = try b.cache_root.join(b.allocator, &.{
            "o", &digest, out_name,
        });
        return;
    }

    const digest = man.final();

    const sub_path = b.pathJoin(&.{ "o", &digest, out_name });
    const sub_path_dirname = std.fs.path.dirname(sub_path).?;
    const out_path = try b.cache_root.join(b.allocator, &.{sub_path});

    b.cache_root.handle.makePath(sub_path_dirname) catch |err| {
        return step.fail("unable to make path '{}{s}': {s}", .{
            b.cache_root, sub_path_dirname, @errorName(err),
        });
    };
    try argv_list.append("-o");
    try argv_list.append(out_path);

    var child = std.process.Child.init(argv_list.items, b.allocator);
    child.cwd = b.build_root.path;
    child.cwd_dir = b.build_root.handle;
    child.env_map = &b.graph.env_map;

    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Ignore;
    child.stderr_behavior = .Pipe;

    try child.spawn();
    const stderr = try child.stderr.?.reader().readAllAlloc(b.allocator, 10 * 1024 * 1024);
    const term = try child.wait();

    switch (term) {
        .Exited => |code| {
            if (code != 0) {
                return step.fail(
                    "failed to translate {s}:\n{s}",
                    .{ resolved_source_path, stderr },
                );
            }
        },
        .Signal, .Stopped, .Unknown => {
            return step.fail(
                "command to translate {s} failed unexpectedly",
                .{resolved_source_path},
            );
        },
    }

    translate_c.output_file.path = out_path;
    try man.writeManifest();
}
