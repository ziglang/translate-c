#include <stdlib.h>
#include <string.h>
extern int foo[];
int global_arr[] = {1, 2, 3};
char global_string[] = "hello";
int main(int argc, char *argv[]) {
    if (global_arr[2] != 3) abort();
    if (strlen(global_string) != 5) abort();
    const char *const_str = "hello";
    if (strcmp(const_str, "hello") != 0) abort();
    char empty_str[] = "";
    if (strlen(empty_str) != 0) abort();
    char hello[] = "hello";
    if (strlen(hello) != 5 || sizeof(hello) != 6) abort();
    int empty[] = {};
    if (sizeof(empty) != 0) abort();
    int bar[] = {42};
    if (bar[0] != 42) abort();
    bar[0] = 43;
    if (bar[0] != 43) abort();
    int baz[] = {1, [42] = 123, 456};
    if (baz[42] != 123 || baz[43] != 456) abort();
    if (sizeof(baz) != sizeof(int) * 44) abort();
    const char *const names[] = {"first", "second", "third"};
    if (strcmp(names[2], "third") != 0) abort();
    char catted_str[] = "abc" "def";
    if (strlen(catted_str) != 6 || sizeof(catted_str) != 7) abort();
    char catted_trunc_str[2] = "abc" "def";
    if (sizeof(catted_trunc_str) != 2 || catted_trunc_str[0] != 'a' || catted_trunc_str[1] != 'b') abort();
    char big_array_utf8lit[10] = "💯";
    if (strcmp(big_array_utf8lit, "💯") != 0 || big_array_utf8lit[9] != 0) abort();
    return 0;
}

// run
// expect=fail
