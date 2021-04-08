const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    const mode = b.standardReleaseOptions();

    const lib = b.addStaticLibrary("ini", "src/lib.zig");
    lib.bundle_compiler_rt = true;
    lib.addIncludeDir("src");
    lib.linkLibC();
    lib.setBuildMode(mode);
    lib.install();

    const example_c = b.addExecutable("example-c", null);
    example_c.addCSourceFile("example/example.c", &[_][]const u8{ "-Wall", "-Wextra", "-pedantic" });
    example_c.addIncludeDir("src");
    example_c.linkLibrary(lib);
    example_c.linkLibC();
    example_c.setBuildMode(mode);
    example_c.install();

    const example_zig = b.addExecutable("example-zig", "example/example.zig");
    example_zig.addPackagePath("ini", "src/ini.zig");
    example_zig.setBuildMode(mode);
    example_zig.install();

    var main_tests = b.addTest("src/test.zig");
    main_tests.setBuildMode(mode);

    var binding_tests = b.addTest("src/lib-test.zig");
    binding_tests.addIncludeDir("src");
    binding_tests.linkLibrary(lib);
    binding_tests.linkLibC();
    binding_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);
    test_step.dependOn(&binding_tests.step);
}
