const std = @import("std");
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

pub fn main() !void {
    const file = try std.fs.cwd().openFile("example.ini", .{});
    defer file.close();

    var parser = ini.parse(std.testing.allocator, file.reader());
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
