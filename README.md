# INI parser library

This is a very simple ini-parser library that provides:

- Raw record reading
- Leading/trailing whitespace removal
- comments based on `;` and `#`
- Zig API
- C API

## Example

Please see the flolder `example`!

## Install

version: zig `0.12.0` or higher

1. Add to `build.zig.zon`

```sh
# It is recommended to replace the following branch with commit id
zig fetch --save https://github.com/ziglibs/ini/archive/master.tar.gz
# Of course, you can also use git+https to fetch this package!
```

2. Config `build.zig`

Add this:

```zig
// To standardize development, maybe you should use `lazyDependency()` instead of `dependency()`
// more info to see: https://ziglang.org/download/0.12.0/release-notes.html#toc-Lazy-Dependencies
const ini = b.dependency("ini", .{
    .target = target,
    .optimize = optimize,
});

// add module
exe.root_module.addImport("ini", ini.module("ini"));
```
