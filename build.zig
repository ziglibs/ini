const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});

    _ = b.addModule("ini", .{
        .source_file = .{
            .path = "src/ini.zig",
        },
    });

    const lib = b.addStaticLibrary(.{
        .name = "ini",
        .root_source_file = .{ .path = "src/lib.zig" },
        .target = b.standardTargetOptions(.{}),
        .optimize = optimize,
    });
    lib.bundle_compiler_rt = true;
    lib.addIncludePath(.{ .path = "src" });
    lib.linkLibC();

    b.installArtifact(lib);

    const example_c = b.addExecutable(.{
        .name = "example-c",
        .optimize = optimize,
    });
    example_c.addCSourceFile(.{
        .file = .{
            .path = "example/example.c",
        },
        .flags = &.{
            "-Wall",
            "-Wextra",
            "-pedantic",
        },
    });
    example_c.addIncludePath(.{ .path = "src" });
    example_c.linkLibrary(lib);
    example_c.linkLibC();

    b.installArtifact(example_c);

    const example_zig = b.addExecutable(.{
        .name = "example-zig",
        .root_source_file = .{ .path = "example/example.zig" },
        .optimize = optimize,
    });
    example_zig.addModule("ini", b.modules.get("ini").?);

    b.installArtifact(example_zig);

    var main_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/test.zig" },
        .optimize = optimize,
    });

    var binding_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/lib-test.zig" },
        .optimize = optimize,
    });
    binding_tests.addIncludePath(.{ .path = "src" });
    binding_tests.linkLibrary(lib);
    binding_tests.linkLibC();

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);
    test_step.dependOn(&binding_tests.step);
}
