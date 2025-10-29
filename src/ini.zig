const std = @import("std");

/// An entry in a ini file. Each line that contains non-whitespace text can
/// be categorized into a record type.
pub const Record = union(enum) {
    /// A section heading enclosed in `[` and `]`. The brackets are not included.
    section: [:0]const u8,

    /// A line that contains a key-value pair separated by `=`.
    /// Both key and value have the excess whitespace trimmed.
    /// Both key and value allow escaping with C string syntax.
    property: KeyValue,

    /// A line that is either escaped as a C string or contains no `=`
    enumeration: [:0]const u8,
};

pub const KeyValue = struct {
    key: [:0]const u8,
    value: [:0]const u8,
};

const whitespace = " \r\t\x00";

/// WARNING:
/// This function is not a general purpose function but
/// requires to be executed on slices of the line_buffer *after*
/// the NUL terminator appendix.
/// This function will override the character after the slice end,
/// so make sure there is one available!
fn insertNulTerminator(slice: []const u8) [:0]const u8 {
    const mut_ptr = @as([*]u8, @ptrFromInt(@intFromPtr(slice.ptr)));
    mut_ptr[slice.len] = 0;
    return mut_ptr[0..slice.len :0];
}

pub const Parser = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    line_buffer: std.array_list.Managed(u8),
    reader: *std.io.Reader,
    comment_characters: []const u8,

    pub fn deinit(self: *Self) void {
        self.line_buffer.deinit();
        self.* = undefined;
    }

    pub fn next(self: *Self) !?Record {
        var write_buffer: [1024]u8 = undefined;
        var old_writer_adapter = self.line_buffer.writer().adaptToNewApi(&write_buffer);
        var writer = &old_writer_adapter.new_interface;
        self.line_buffer.clearRetainingCapacity();
        while (true) {
            _ = try self.reader.streamDelimiterLimit(writer, '\n', .limited(4096));
            try writer.flush();
            const discarded = self.reader.discard(.limited(1)) catch |e| blk: {
                switch (e) {
                    error.EndOfStream => {
                        if (self.line_buffer.items.len == 0)
                            return null;
                        break :blk 0;
                    },
                    else => return e,
                }
            };
            if (self.line_buffer.items.len == 0 and discarded == 0)
                return null;
            try self.line_buffer.append(0); // append guaranteed space for sentinel

            var line: []const u8 = self.line_buffer.items;
            var last_index: usize = 0;

            // handle comments and escaping
            while (last_index < line.len) {
                if (std.mem.indexOfAnyPos(u8, line, last_index, self.comment_characters)) |index| {
                    // escape character if needed, then skip it (it's not a comment)
                    if (index > 0) {
                        const previous_index = index - 1;
                        const previous_char = line[previous_index];

                        if (previous_char == '\\') {
                            _ = self.line_buffer.orderedRemove(previous_index);
                            line = self.line_buffer.items;

                            last_index = index + 1;
                            continue;
                        }
                    }

                    line = std.mem.trim(u8, line[0..index], whitespace);
                } else {
                    line = std.mem.trim(u8, line, whitespace);
                }

                break;
            }

            if (line.len == 0) {
                self.line_buffer.clearRetainingCapacity();
                continue;
            }

            if (std.mem.startsWith(u8, line, "[") and std.mem.endsWith(u8, line, "]")) {
                return Record{ .section = insertNulTerminator(line[1 .. line.len - 1]) };
            }

            if (std.mem.indexOfScalar(u8, line, '=')) |index| {
                return Record{
                    .property = KeyValue{
                        // note: the key *might* replace the '=' in the slice with 0!
                        .key = insertNulTerminator(std.mem.trim(u8, line[0..index], whitespace)),
                        .value = insertNulTerminator(std.mem.trim(u8, line[index + 1 ..], whitespace)),
                    },
                };
            }

            return Record{ .enumeration = insertNulTerminator(line) };
        }
    }
};

/// Returns a new parser that can read the ini structure
pub fn parse(allocator: std.mem.Allocator, reader: *std.io.Reader, comment_characters: []const u8) Parser {
    return Parser{
        .allocator = allocator,
        .line_buffer = std.array_list.Managed(u8).init(allocator),
        .reader = reader,
        .comment_characters = comment_characters,
    };
}
