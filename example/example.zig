const std = @import("std");
const ini = @import("ini");

pub fn main() !void {
    const file = try std.fs.cwd().openFile("example.ini", .{});
    defer file.close();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() != .ok) @panic("memory leaked");

    var read_buffer: [1024]u8 = undefined;
    var file_reader = file.reader(&read_buffer);
    var parser = ini.parse(gpa.allocator(), &file_reader.interface, ";#");
    defer parser.deinit();

    var write_buffer: [1024]u8 = undefined;
    var file_writer = std.fs.File.stdout().writer(&write_buffer);
    var writer = &file_writer.interface;
    defer writer.flush() catch @panic("Could not flush to stdout");

    while (try parser.next()) |record| {
        switch (record) {
            .section => |heading| try writer.print("[{s}]\n", .{heading}),
            .property => |kv| try writer.print("{s} = {s}\n", .{ kv.key, kv.value }),
            .enumeration => |value| try writer.print("{s}\n", .{value}),
        }
    }
}
