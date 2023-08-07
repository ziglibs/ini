const std = @import("std");
const ini = @import("ini.zig");

const c = @cImport({
    @cInclude("ini.h");
});

const Record = extern struct {
    type: Type,
    value: Data,

    const Type = enum(c.ini_RecordType) {
        nul = 0,
        section = 1,
        property = 2,
        enumeration = 3,
    };

    const Data = extern union {
        section: [*:0]const u8,
        property: KeyValuePair,
        enumeration: [*:0]const u8,
    };

    const KeyValuePair = extern struct {
        key: [*:0]const u8,
        value: [*:0]const u8,
    };
};

const BufferParser = struct {
    stream: std.io.FixedBufferStream([]const u8),
    parser: ini.Parser(std.io.FixedBufferStream([]const u8).Reader),
};

const IniParser = union(enum) {
    buffer: BufferParser,
    file: ini.Parser(CReader),
};

const IniError = enum(c.ini_Error) {
    success = 0,
    out_of_memory = 1,
    io = 2,
    invalid_data = 3,
};

comptime {
    if (@sizeOf(c.ini_Parser) < @sizeOf(IniParser))
        @compileError(std.fmt.comptimePrint("ini_Parser struct in header is too small. Please set the char array to at least {d} chars!", .{@sizeOf(IniParser)}));
    if (@alignOf(c.ini_Parser) < @alignOf(IniParser))
        @compileError("align mismatch: ini_Parser struct does not match IniParser");

    if (@sizeOf(c.ini_Record) != @sizeOf(Record))
        @compileError("size mismatch: ini_Record struct does not match Record!");
    if (@alignOf(c.ini_Record) != @alignOf(Record))
        @compileError("align mismatch: ini_Record struct does not match Record!");

    if (@sizeOf(c.ini_KeyValuePair) != @sizeOf(Record.KeyValuePair))
        @compileError("size mismatch: ini_KeyValuePair struct does not match Record.KeyValuePair!");
    if (@alignOf(c.ini_KeyValuePair) != @alignOf(Record.KeyValuePair))
        @compileError("align mismatch: ini_KeyValuePair struct does not match Record.KeyValuePair!");
}

export fn ini_create_buffer(parser: *IniParser, data: [*]const u8, length: usize) void {
    parser.* = IniParser{
        .buffer = .{
            .stream = std.io.fixedBufferStream(data[0..length]),
            .parser = undefined,
        },
    };
    // this is required to have the parser store a pointer to the stream.
    parser.buffer.parser = ini.parse(std.heap.c_allocator, parser.buffer.stream.reader());
}

export fn ini_create_file(parser: *IniParser, file: *std.c.FILE) void {
    parser.* = IniParser{
        .file = ini.parse(std.heap.c_allocator, cReader(file)),
    };
}

export fn ini_destroy(parser: *IniParser) void {
    switch (parser.*) {
        .buffer => |*p| p.parser.deinit(),
        .file => |*p| p.deinit(),
    }
    parser.* = undefined;
}

const ParseError = error{ OutOfMemory, StreamTooLong } || CReader.Error;

fn mapError(err: ParseError) IniError {
    return switch (err) {
        error.OutOfMemory => IniError.out_of_memory,
        error.StreamTooLong => IniError.invalid_data,
        else => IniError.io,
    };
}

export fn ini_next(parser: *IniParser, record: *Record) IniError {
    const src_record_or_null: ?ini.Record = switch (parser.*) {
        .buffer => |*p| p.parser.next() catch |e| return mapError(e),
        .file => |*p| p.next() catch |e| return mapError(e),
    };

    if (src_record_or_null) |src_record| {
        record.* = switch (src_record) {
            .section => |heading| Record{
                .type = .section,
                .value = .{ .section = heading.ptr },
            },
            .enumeration => |enumeration| Record{
                .type = .enumeration,
                .value = .{ .enumeration = enumeration.ptr },
            },
            .property => |property| Record{
                .type = .property,
                .value = .{ .property = .{
                    .key = property.key.ptr,
                    .value = property.value.ptr,
                } },
            },
        };
    } else {
        record.* = Record{
            .type = .nul,
            .value = undefined,
        };
    }

    return .success;
}

const CReader = std.io.Reader(*std.c.FILE, std.fs.File.ReadError, cReaderRead);

fn cReader(c_file: *std.c.FILE) CReader {
    return .{ .context = c_file };
}

fn cReaderRead(c_file: *std.c.FILE, bytes: []u8) std.fs.File.ReadError!usize {
    const amt_read = std.c.fread(bytes.ptr, 1, bytes.len, c_file);
    if (amt_read >= 0) return amt_read;
    switch (@as(std.os.E, @enumFromInt(std.c._errno().*))) {
        .SUCCESS => unreachable,
        .INVAL => unreachable,
        .FAULT => unreachable,
        .AGAIN => unreachable, // this is a blocking API
        .BADF => unreachable, // always a race condition
        .DESTADDRREQ => unreachable, // connect was never called
        .DQUOT => return error.DiskQuota,
        .FBIG => return error.FileTooBig,
        .IO => return error.InputOutput,
        .NOSPC => return error.NoSpaceLeft,
        .PERM => return error.AccessDenied,
        .PIPE => return error.BrokenPipe,
        else => |err| return std.os.unexpectedErrno(err),
    }
}
