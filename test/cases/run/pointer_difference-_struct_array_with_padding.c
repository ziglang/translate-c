#include <stdlib.h>
#include <stddef.h>
#define SIZE 10
typedef struct my_struct {
    int x;
    char c;
    int y;
} my_struct_t;
int main() {
    my_struct_t foo[SIZE];
    my_struct_t *start = &foo[0];
    my_struct_t *one_past_end = start + SIZE;
    ptrdiff_t diff = one_past_end - start;
    int diff_int = one_past_end - start;
    if (diff != SIZE || diff_int != SIZE) abort();
    diff = start - one_past_end;
    if (diff != -SIZE) abort();
    return 0;
}

// run
