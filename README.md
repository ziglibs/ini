# INI parser library

This is a very simple ini-parser library that provides:
- Raw record reading
- Leading/trailing whitespace removal
- Comments
- Zig API
- C API

## Usage example

### Zig 

```zig
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
```

### C

```c
#include <ini.h>

#include <stdio.h>
#include <stdbool.h>

int main() {
  FILE * f = fopen("example.ini", "r");
  if(!f)
    return 1;

  struct ini_Parser parser;
  char read_buffer[1024] = {0};
  ini_create_file(&parser, read_buffer, sizeof read_buffer, f, ";#", 2);

  struct ini_Record record;
  while(true)
  {
    enum ini_Error error = ini_next(&parser, &record);
    if(error != INI_SUCCESS)
      goto cleanup;

    switch(record.type) {
      case INI_RECORD_NUL: goto done;
      case INI_RECORD_SECTION:
        printf("[%s]\n", record.section);
        break;
      case INI_RECORD_PROPERTY:
        printf("%s = %s\n", record.property.key, record.property.value);
        break;
      case INI_RECORD_ENUMERATION:
        printf("%s\n", record.enumeration);
        break;
    }

  }
done:

cleanup:
  ini_destroy(&parser);
  fclose(f);
  return 0;
}
```
