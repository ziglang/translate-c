#include <stdlib.h>
#include <stddef.h>
#define SIZE 10
int main() {
    int foo[SIZE];
    int *start = &foo[0];
    int *one_past_end = start + SIZE;
    ptrdiff_t diff = one_past_end - start;
    char diff_char = one_past_end - start;
    if (diff != SIZE || diff_char != SIZE) abort();
    diff = start - one_past_end;
    if (diff != -SIZE) abort();
    if (one_past_end - foo != SIZE) abort();
    if ((one_past_end - 1) - foo != SIZE - 1) abort();
    if ((start + 1) - foo != 1) abort();
    return 0;
}

// run
// expect=fail
