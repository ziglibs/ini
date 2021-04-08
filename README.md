# INI parser library

This is a very simple ini-parser library that provides:
- Raw record reading
- Leading/trailing whitespace removal
- comments based on `;` and `#`
- Zig API
- C API

## Usage example

### Zig 

```zig
const std = @import("std");
const ini = @import("ini");

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
```

### C

```c
#include <ini.h>

#include <stdio.h>
#include <stdbool.h>

int main() {
  FILE * f = fopen("example.ini", "rb");
  if(!f)
    return 1;
  
  struct ini_Parser parser;
  ini_create_file(&parser, f);

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