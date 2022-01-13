#ifndef ZIG_INI_H
#define ZIG_INI_H

#include <stddef.h>
#include <stdio.h>
#include <stdalign.h>

/// Opaque parser type. Consider the bytes in this struct
/// as "implementation defined".
/// This must also be fixed memory and must not be copied
/// after being initialized with `ini_create_*`!
struct ini_Parser
{
  alignas(16) char opaque[128];
};

enum ini_RecordType : int
{
  INI_RECORD_NUL = 0,
  INI_RECORD_SECTION = 1,
  INI_RECORD_PROPERTY = 2,
  INI_RECORD_ENUMERATION = 3,
};

struct ini_KeyValuePair
{
    char const * key;
    char const * value;
};

struct ini_Record
{
  enum ini_RecordType type;
  union {
    char const * section;
    struct ini_KeyValuePair property;
    char const * enumeration;
  };
};

enum ini_Error
{
  INI_SUCCESS = 0,
  INI_ERR_OUT_OF_MEMORY = 1,
  INI_ERR_IO = 2,
  INI_ERR_INVALID_DATA = 3,
};

extern void ini_create_buffer(
  struct ini_Parser  * parser,
  char const * data,
  size_t length
);

extern void ini_create_file(
  struct ini_Parser  * parser,
  FILE * file
);

extern void ini_destroy(struct ini_Parser  * parser);

extern enum ini_Error ini_next(struct ini_Parser * parser, struct ini_Record * record);

#endif
