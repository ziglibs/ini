# INI parser library

This is a very simple ini-parser library that provides:
- Raw record reading
- Leading/trailing whitespace removal
- (not yet) string escaping
- comments based on `;` and `#`
- Zig API
- (not yet) C API

## Usage example

### Zig

```zig
const ini = @import("ini");

const config =
    \\[Meta]
    \\author = xq
    \\library = ini
    \\
    \\[Albums]
    \\Thriller
    \\Back in Black
    \\Bat Out of Hell
    \\The Dark Side of the Moon
;

test {
    var parser = ini.parse(std.testing.allocator, std.io.fixedBufferStream(config).reader());
    defer parser.deinit();

    var writer = std.io.getStdOut().writer();

    while (try parser.next()) |record| {
        switch (record) {
            .section => |heading| try writer.print("[{s}]\n", .{heading}),
            .property => |kv| try writer.print("{s} = {s}\n", .{ kv.key, kv.value }),
            .enumeration => |value| try writer.print("{s}\n", .{value}),
        }
    }
}
```