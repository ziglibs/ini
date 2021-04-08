const std = @import("std");

const c = @cImport({
    @cInclude("ini.h");
});

test "parser create/destroy" {
    var buffer: c.ini_Parser = undefined;
    c.ini_create_buffer(&buffer, "", 0);
    c.ini_destroy(&buffer);
}

fn expectNull(record: c.ini_Record) void {
    std.testing.expectEqual(c.ini_RecordType.INI_RECORD_NUL, record.type);
}

fn expectSection(heading: []const u8, record: c.ini_Record) void {
    std.testing.expectEqual(c.ini_RecordType.INI_RECORD_SECTION, record.type);
    std.testing.expectEqualStrings(heading, std.mem.span(record.unnamed_0.section));
}

fn expectKeyValue(key: []const u8, value: []const u8, record: c.ini_Record) void {
    std.testing.expectEqual(c.ini_RecordType.INI_RECORD_PROPERTY, record.type);
    std.testing.expectEqualStrings(key, std.mem.span(record.unnamed_0.property.key));
    std.testing.expectEqualStrings(value, std.mem.span(record.unnamed_0.property.value));
}

fn expectEnumeration(enumeration: []const u8, record: c.ini_Record) void {
    std.testing.expectEqual(c.ini_RecordType.INI_RECORD_ENUMERATION, record.type);
    std.testing.expectEqualStrings(enumeration, std.mem.span(record.unnamed_0.enumeration));
}

fn parseNext(parser: *c.ini_Parser) !c.ini_Record {
    var record: c.ini_Record = undefined;
    const err = c.ini_next(parser, &record);
    switch (err) {
        .INI_SUCCESS => return record,
        .INI_ERR_OUT_OF_MEMORY => return error.OutOfMemory,
        .INI_ERR_IO => return error.InputOutput,
        .INI_ERR_INVALID_DATA => return error.InvalidData,
        _ => unreachable,
    }
}

fn commonTest(parser: *c.ini_Parser) !void {
    expectSection("Meta", try parseNext(parser));
    expectKeyValue("author", "xq", try parseNext(parser));
    expectKeyValue("library", "ini", try parseNext(parser));

    expectSection("Albums", try parseNext(parser));

    expectEnumeration("Thriller", try parseNext(parser));
    expectEnumeration("Back in Black", try parseNext(parser));
    expectEnumeration("Bat Out of Hell", try parseNext(parser));
    expectEnumeration("The Dark Side of the Moon", try parseNext(parser));

    expectNull(try parseNext(parser));
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
