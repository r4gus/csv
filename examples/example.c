#include "../include/csv.h"
#include <stdio.h>
#include <string.h>

int main(int argc, char** argv) {
    Csv csv = csv_open("examples/file1.csv");

    if (csv == NULL) {
        printf("error: can't open file\n");
        exit(1);
    }

    char* new_row = "Sugar,Pierre,45"; 
    if (csv_append(csv, new_row, strlen(new_row)) < 0) {
        printf("error: unable to append string to file\n");
        exit(1);
    }

    Row row;
    while (row = csv_next(csv)) {
        char* s;
        size_t l;
        while (s = csv_row_next(row, &l)) {
            printf("%.*s ", l, s);
        }
        printf("\n");
    }

    csv_close(csv);
    return 0;
}
