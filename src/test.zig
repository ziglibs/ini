const std = @import("std");

const ini = @import("ini.zig");
const parse = ini.parse;
const Record = ini.Record;

fn expectNull(record: ?Record) !void {
    try std.testing.expectEqual(@as(?Record, null), record);
}

fn expectSection(heading: []const u8, record: ?Record) !void {
    try std.testing.expectEqualStrings(heading, record.?.section);
}

fn expectKeyValue(key: []const u8, value: []const u8, record: ?Record) !void {
    try std.testing.expectEqualStrings(key, record.?.property.key);
    try std.testing.expectEqualStrings(value, record.?.property.value);
}

fn expectEnumeration(enumeration: []const u8, record: ?Record) !void {
    try std.testing.expectEqualStrings(enumeration, record.?.enumeration);
}

test "empty file" {
    var stream = std.io.Reader.fixed("");
    var parser = parse(std.testing.allocator, &stream, ";#");
    defer parser.deinit();

    try expectNull(try parser.next());
    try expectNull(try parser.next());
    try expectNull(try parser.next());
    try expectNull(try parser.next());
}

test "section" {
    var stream = std.io.Reader.fixed("[Hello]");
    var parser = parse(std.testing.allocator, &stream, ";#");
    defer parser.deinit();

    try expectSection("Hello", try parser.next());
    try expectNull(try parser.next());
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
        var stream = std.io.Reader.fixed(pattern);
        var parser = parse(std.testing.allocator, &stream, ";#");
        defer parser.deinit();

        try expectKeyValue("key", "value", try parser.next());
        try expectNull(try parser.next());
    }
}

test "enumeration" {
    var stream = std.io.Reader.fixed("enum");
    var parser = parse(std.testing.allocator, &stream, ";#");
    defer parser.deinit();

    try expectEnumeration("enum", try parser.next());
    try expectNull(try parser.next());
}

test "empty line skipping" {
    var stream = std.io.Reader.fixed("item a\r\n\r\n\r\nitem b");
    var parser = parse(std.testing.allocator, &stream, ";#");
    defer parser.deinit();

    try expectEnumeration("item a", try parser.next());
    try expectEnumeration("item b", try parser.next());
    try expectNull(try parser.next());
}

test "multiple sections" {
    var stream = std.io.Reader.fixed("  [Hello] \r\n[Foo Bar]\n[Hello!]\n");
    var parser = parse(std.testing.allocator, &stream, ";#");
    defer parser.deinit();

    try expectSection("Hello", try parser.next());
    try expectSection("Foo Bar", try parser.next());
    try expectSection("Hello!", try parser.next());
    try expectNull(try parser.next());
}

test "multiple properties" {
    var stream = std.io.Reader.fixed("a = b\r\nc =\r\nkey value = core property");
    var parser = parse(std.testing.allocator, &stream, ";#");
    defer parser.deinit();

    try expectKeyValue("a", "b", try parser.next());
    try expectKeyValue("c", "", try parser.next());
    try expectKeyValue("key value", "core property", try parser.next());
    try expectNull(try parser.next());
}

test "multiple enumeration" {
    var stream = std.io.Reader.fixed(" a  \n b  \r\n c  ");
    var parser = parse(std.testing.allocator, &stream, ";#");
    defer parser.deinit();

    try expectEnumeration("a", try parser.next());
    try expectEnumeration("b", try parser.next());
    try expectEnumeration("c", try parser.next());
    try expectNull(try parser.next());
}

test "mixed data" {
    var stream = std.io.Reader.fixed(
        \\[Meta]
        \\author = xq
        \\library = ini
        \\
        \\[Albums]
        \\Thriller
        \\Back in Black
        \\Bat Out of Hell
        \\The Dark Side of the Moon
    );
    var parser = parse(std.testing.allocator, &stream, ";#");
    defer parser.deinit();

    try expectSection("Meta", try parser.next());
    try expectKeyValue("author", "xq", try parser.next());
    try expectKeyValue("library", "ini", try parser.next());

    try expectSection("Albums", try parser.next());

    try expectEnumeration("Thriller", try parser.next());
    try expectEnumeration("Back in Black", try parser.next());
    try expectEnumeration("Bat Out of Hell", try parser.next());
    try expectEnumeration("The Dark Side of the Moon", try parser.next());

    try expectNull(try parser.next());
}

test "# comments" {
    var stream = std.io.Reader.fixed(
        \\[section] # comment
        \\key = value # comment
        \\enum # comment
    );
    var parser = parse(std.testing.allocator, &stream, ";#");
    defer parser.deinit();

    try expectSection("section", try parser.next());
    try expectKeyValue("key", "value", try parser.next());
    try expectEnumeration("enum", try parser.next());

    try expectNull(try parser.next());
}

test "; comments" {
    var stream = std.io.Reader.fixed(
        \\[section] ; comment
        \\key = value ; comment
        \\enum ; comment
    );
    var parser = parse(std.testing.allocator, &stream, ";#");
    defer parser.deinit();

    try expectSection("section", try parser.next());
    try expectKeyValue("key", "value", try parser.next());
    try expectEnumeration("enum", try parser.next());

    try expectNull(try parser.next());
}

test "comment escaping" {
    var stream = std.io.Reader.fixed(
        \\# This comment should be ignored
        \\#
        \\# Amazing!
        \\names = Budgie;GNOME # Don't mind me
        \\asterisk = \# # An asterisk as a comment character? Surely that can't break anything... right?
        \\escaped = \#
        \\no_value = #This doesn't have any value
    );
    var parser = parse(std.testing.allocator, &stream, "#");
    defer parser.deinit();

    try expectKeyValue("names", "Budgie;GNOME", try parser.next());
    try expectKeyValue("asterisk", "#", try parser.next());
    try expectKeyValue("escaped", "#", try parser.next());
    try expectKeyValue("no_value", "", try parser.next());

    try expectNull(try parser.next());
}

test "comment character selection" {
    var stream = std.io.Reader.fixed(
        \\# This is a comment
        \\? But this is also one!
        \\just_a_key = value
    );
    var parser = parse(std.testing.allocator, &stream, "#?");
    defer parser.deinit();

    try expectKeyValue("just_a_key", "value", try parser.next());

    try expectNull(try parser.next());
}
