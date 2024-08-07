const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    _ = b.addModule("ini", .{
        .root_source_file = b.path("src/ini.zig"),
    });

    const lib = b.addStaticLibrary(.{
        .name = "ini",
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
    });

    lib.bundle_compiler_rt = true;
    lib.addIncludePath(b.path("src"));
    lib.linkLibC();

    b.installArtifact(lib);

    const example_c = b.addExecutable(.{
        .name = "example-c",
        .optimize = optimize,
        .target = target,
    });
    example_c.addCSourceFile(.{
        .file = b.path("example/example.c"),
        .flags = &.{
            "-Wall",
            "-Wextra",
            "-pedantic",
        },
    });
    example_c.addIncludePath(b.path("src"));
    example_c.linkLibrary(lib);
    example_c.linkLibC();

    b.installArtifact(example_c);

    const example_zig = b.addExecutable(.{
        .name = "example-zig",
        .root_source_file = b.path("example/example.zig"),
        .optimize = optimize,
        .target = target,
    });
    example_zig.root_module.addImport("ini", b.modules.get("ini").?);

    b.installArtifact(example_zig);

    var main_tests = b.addTest(.{
        .root_source_file = b.path("src/test.zig"),
        .optimize = optimize,
    });

    var binding_tests = b.addTest(.{
        .root_source_file = b.path("src/lib-test.zig"),
        .optimize = optimize,
    });
    binding_tests.addIncludePath(b.path("src"));
    binding_tests.linkLibrary(lib);
    binding_tests.linkLibC();

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);
    test_step.dependOn(&binding_tests.step);
}
