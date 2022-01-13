const std = @import("std");

const c = @cImport({
    @cInclude("ini.h");
});

test "parser create/destroy" {
    var buffer: c.ini_Parser = undefined;
    c.ini_create_buffer(&buffer, "", 0);
    c.ini_destroy(&buffer);
}

fn expectNull(record: c.ini_Record) !void {
    try std.testing.expectEqual(c.INI_RECORD_NUL, record.type);
}

fn expectSection(heading: []const u8, record: c.ini_Record) !void {
    try std.testing.expectEqual(c.INI_RECORD_SECTION, record.type);
    try std.testing.expectEqualStrings(heading, std.mem.span(record.unnamed_0.section));
}

fn expectKeyValue(key: []const u8, value: []const u8, record: c.ini_Record) !void {
    try std.testing.expectEqual(c.INI_RECORD_PROPERTY, record.type);
    try std.testing.expectEqualStrings(key, std.mem.span(record.unnamed_0.property.key));
    try std.testing.expectEqualStrings(value, std.mem.span(record.unnamed_0.property.value));
}

fn expectEnumeration(enumeration: []const u8, record: c.ini_Record) !void {
    try std.testing.expectEqual(c.INI_RECORD_ENUMERATION, record.type);
    try std.testing.expectEqualStrings(enumeration, std.mem.span(record.unnamed_0.enumeration));
}

fn parseNext(parser: *c.ini_Parser) !c.ini_Record {
    var record: c.ini_Record = undefined;
    const err = c.ini_next(parser, &record);
    switch (err) {
        c.INI_SUCCESS => return record,
        c.INI_ERR_OUT_OF_MEMORY => return error.OutOfMemory,
        c.INI_ERR_IO => return error.InputOutput,
        c.INI_ERR_INVALID_DATA => return error.InvalidData,
        else => unreachable,
    }
}

fn commonTest(parser: *c.ini_Parser) !void {
    try expectSection("Meta", try parseNext(parser));
    try expectKeyValue("author", "xq", try parseNext(parser));
    try expectKeyValue("library", "ini", try parseNext(parser));

    try expectSection("Albums", try parseNext(parser));

    try expectEnumeration("Thriller", try parseNext(parser));
    try expectEnumeration("Back in Black", try parseNext(parser));
    try expectEnumeration("Bat Out of Hell", try parseNext(parser));
    try expectEnumeration("The Dark Side of the Moon", try parseNext(parser));

    try expectNull(try parseNext(parser));
}

test "buffer parser" {
    const slice =
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

    var parser: c.ini_Parser = undefined;
    c.ini_create_buffer(&parser, slice, slice.len);
    defer c.ini_destroy(&parser);

    try commonTest(&parser);
}

test "file parser" {
    var file = c.fopen("example/example.ini", "rb") orelse unreachable;
    defer _ = c.fclose(file);

    var parser: c.ini_Parser = undefined;
    c.ini_create_file(&parser, file);
    defer c.ini_destroy(&parser);

    try commonTest(&parser);
}
