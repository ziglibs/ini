const std = @import("std");

pub fn build(b: *std.Build) void {
    // get optimize and target
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    // expose the ini module
    const ini = b.addModule("ini", .{
        .root_source_file = b.path("src/ini.zig"),
    });

    // create c lib
    const c_lib = createCLib(b, optimize, target);

    // for zig example
    example(b, optimize, target, ini);

    // for c example
    cExample(b, optimize, target, c_lib);

    // for uint test
    unitTest(b, optimize, target, ini, c_lib);
}

fn createCLib(b: *std.Build, optimize: std.builtin.OptimizeMode, target: std.Build.ResolvedTarget) *std.Build.Step.Compile {
    const lib = b.addStaticLibrary(.{
        .name = "ini",
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
    });

    lib.bundle_compiler_rt = true;
    lib.addIncludePath(.{ .path = "src" });
    lib.linkLibC();

    const intall_step = b.addInstallArtifact(lib, .{});

    const install_step = b.step("clib", "install c lib");

    install_step.dependOn(&intall_step.step);

    return lib;
}

fn example(b: *std.Build, optimize: std.builtin.OptimizeMode, target: std.Build.ResolvedTarget, ini: *std.Build.Module) void {
    const example_zig = b.addExecutable(.{
        .name = "example-zig",
        .root_source_file = b.path("example/example.zig"),
        .optimize = optimize,
        .target = target,
    });
    example_zig.root_module.addImport("ini", ini);

    const intall_step = b.addInstallArtifact(example_zig, .{});
    const install_step = b.step("example", "install zig example");
    install_step.dependOn(&intall_step.step);
}

fn cExample(b: *std.Build, optimize: std.builtin.OptimizeMode, target: std.Build.ResolvedTarget, c_lib: *std.Build.Step.Compile) void {
    const c_example = b.addExecutable(.{
        .name = "example-c",
        .optimize = optimize,
        .target = target,
    });

    c_example.addCSourceFile(.{
        .file = b.path("example/example.c"),
        .flags = &.{
            "-Wall",
            "-Wextra",
            "-pedantic",
        },
    });

    c_example.addIncludePath(.{ .path = "src" });
    c_example.linkLibrary(c_lib);
    c_example.linkLibC();

    const intall_step = b.addInstallArtifact(c_example, .{});
    const install_step = b.step("c_example", "install c example");
    install_step.dependOn(&intall_step.step);
}

fn unitTest(b: *std.Build, optimize: std.builtin.OptimizeMode, target: std.Build.ResolvedTarget, ini: *std.Build.Module, c_lib: *std.Build.Step.Compile) void {
    var main_tests = b.addTest(.{
        .root_source_file = b.path("src/test.zig"),
        .optimize = optimize,
        .target = target,
    });
    main_tests.root_module.addImport("ini", ini);

    var binding_tests = b.addTest(.{
        .root_source_file = b.path("src/lib-test.zig"),
        .optimize = optimize,
        .target = target,
    });
    binding_tests.addIncludePath(b.path("src"));
    binding_tests.linkLibrary(c_lib);
    binding_tests.linkLibC();

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&main_tests.step);
    test_step.dependOn(&binding_tests.step);
}
