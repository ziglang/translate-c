pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const all_step = b.step("all", "Run all examples");
    b.default_step = all_step;

    for (b.available_deps) |available_dep| {
        const example_name, _ = available_dep;
        const run_example = b.dependency(example_name, .{
            .target = target,
            .optimize = optimize,
        }).builder.default_step;
        const example_step = b.step(example_name, b.fmt("Run the '{s}' example", .{example_name}));
        example_step.dependOn(run_example);
        all_step.dependOn(example_step);
    }
}
const std = @import("std");
