const std = @import("std");

pub const Record = union(enum) {
    /// A section heading enclosed in `[` and `]`. The brackets are not included.
    section: []const u8,

    /// A line that contains a key-value pair separated by `=`.
    /// Both key and value have the excess whitespace trimmed.
    /// Both key and value allow escaping with C string syntax.
    property: KeyValue,

    /// A line that is either escaped as a C string or contains no `=`
    enumeration: []const u8,
};

pub const KeyValue = struct {
    key: []const u8,
    value: []const u8,
};

fn Iterator(comptime Reader: type) type {
    return struct {
        const Self = @This();

        line_buffer: std.ArrayList(u8),
        reader: Reader,

        pub fn deinit(self: *Self) void {
            self.line_buffer.deinit();
            self.* = undefined;
        }

        pub fn next(self: *Self) !?Record {
            while (true) {
                self.reader.readUntilDelimiterArrayList(&self.line_buffer, '\n', 4096) catch |err| switch (err) {
                    error.EndOfStream => {
                        if (self.line_buffer.items.len == 0)
                            return null;
                    },
                    else => |e| return e,
                };

                const whitespace = " \r\t";
                const line = if (std.mem.indexOfScalar(u8, self.line_buffer.items, '#')) |index|
                    std.mem.trim(u8, self.line_buffer.items[0..index], whitespace)
                else
                    std.mem.trim(u8, self.line_buffer.items, whitespace);
                if (line.len == 0)
                    continue;

                if (std.mem.startsWith(u8, line, "[") and std.mem.endsWith(u8, line, "]")) {
                    return Record{ .section = line[1 .. line.len - 1] };
                }

                // TODO: Implement proper string escaping

                if (std.mem.indexOfScalar(u8, line, '=')) |index| {
                    return Record{ .property = KeyValue{
                        .key = std.mem.trim(u8, line[0..index], whitespace),
                        .value = std.mem.trim(u8, line[index + 1 ..], whitespace),
                    } };
                }

                return Record{ .enumeration = line };
            }
        }
    };
}

/// Returns a new parser that can read the ini structure
pub fn parse(allocator: *std.mem.Allocator, reader: anytype) Iterator(@TypeOf(reader)) {
    return Iterator(@TypeOf(reader)){
        .line_buffer = std.ArrayList(u8).init(allocator),
        .reader = reader,
    };
}

fn expectNull(record: ?Record) void {
    std.testing.expectEqual(@as(?Record, null), record);
}

fn expectSection(heading: []const u8, record: ?Record) void {
    std.testing.expectEqualStrings(heading, record.?.section);
}

fn expectKeyValue(key: []const u8, value: []const u8, record: ?Record) void {
    std.testing.expectEqualStrings(key, record.?.property.key);
    std.testing.expectEqualStrings(value, record.?.property.value);
}

fn expectEnumeration(enumeration: []const u8, record: ?Record) void {
    std.testing.expectEqualStrings(enumeration, record.?.enumeration);
}

test "empty file" {
    var parser = parse(std.testing.allocator, std.io.fixedBufferStream("").reader());
    defer parser.deinit();

    expectNull(try parser.next());
    expectNull(try parser.next());
    expectNull(try parser.next());
    expectNull(try parser.next());
}

test "section" {
    var parser = parse(std.testing.allocator, std.io.fixedBufferStream("[Hello]").reader());
    defer parser.deinit();

    expectSection("Hello", try parser.next());
    expectNull(try parser.next());
}

test "key-value-pair" {
    for (&[_][]const u8{
        "key=value",
        "  key=value",
        "key=value  ",
        "  key=value  ",
        "key  =value",
        "  key  =value",
        "key  =value  ",
        "  key  =value  ",
        "key=  value",
        "  key=  value",
        "key=  value  ",
        "  key=  value  ",
        "key  =  value",
        "  key  =  value",
        "key  =  value  ",
        "  key  =  value  ",
    }) |pattern| {
        var parser = parse(std.testing.allocator, std.io.fixedBufferStream(pattern).reader());
        defer parser.deinit();

        expectKeyValue("key", "value", try parser.next());
        expectNull(try parser.next());
    }
}

test "enumeration" {
    var parser = parse(std.testing.allocator, std.io.fixedBufferStream("enum").reader());
    defer parser.deinit();

    expectEnumeration("enum", try parser.next());
    expectNull(try parser.next());
}

test "empty line skipping" {
    var parser = parse(std.testing.allocator, std.io.fixedBufferStream("item a\r\n\r\n\r\nitem b").reader());
    defer parser.deinit();

    expectEnumeration("item a", try parser.next());
    expectEnumeration("item b", try parser.next());
    expectNull(try parser.next());
}

test "multiple sections" {
    var parser = parse(std.testing.allocator, std.io.fixedBufferStream("  [Hello] \r\n[Foo Bar]\n[Hello!]\n").reader());
    defer parser.deinit();

    expectSection("Hello", try parser.next());
    expectSection("Foo Bar", try parser.next());
    expectSection("Hello!", try parser.next());
    expectNull(try parser.next());
}

test "multiple properties" {
    var parser = parse(std.testing.allocator, std.io.fixedBufferStream("a = b\r\nc =\r\nkey value = core property").reader());
    defer parser.deinit();

    expectKeyValue("a", "b", try parser.next());
    expectKeyValue("c", "", try parser.next());
    expectKeyValue("key value", "core property", try parser.next());
    expectNull(try parser.next());
}

test "multiple enumeration" {
    var parser = parse(std.testing.allocator, std.io.fixedBufferStream(" a  \n b  \r\n c  ").reader());
    defer parser.deinit();

    expectEnumeration("a", try parser.next());
    expectEnumeration("b", try parser.next());
    expectEnumeration("c", try parser.next());
    expectNull(try parser.next());
}

test "mixed data" {
    var parser = parse(std.testing.allocator, std.io.fixedBufferStream(
        \\[Meta]
        \\author = xq
        \\library = ini
        \\
        \\[Albums]
        \\Thriller
        \\Back in Black
        \\Bat Out of Hell
        \\The Dark Side of the Moon
    ).reader());
    defer parser.deinit();

    expectSection("Meta", try parser.next());
    expectKeyValue("author", "xq", try parser.next());
    expectKeyValue("library", "ini", try parser.next());

    expectSection("Albums", try parser.next());

    expectEnumeration("Thriller", try parser.next());
    expectEnumeration("Back in Black", try parser.next());
    expectEnumeration("Bat Out of Hell", try parser.next());
    expectEnumeration("The Dark Side of the Moon", try parser.next());

    expectNull(try parser.next());
}
