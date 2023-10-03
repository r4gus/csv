#include <stdlib.h>

typedef void* Csv;
typedef void* Row;

Csv csv_open(char* path);
void csv_close(Csv csv);
int csv_write(Csv csv, char* path);
Row csv_next(Csv csv);
void csv_reset(Csv csv);
int csv_set(Csv csv, size_t index, char* v, size_t len);
int csv_append(Csv csv, char* v, size_t len);
char* csv_row_next(Row row, size_t* len);
