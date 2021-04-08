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