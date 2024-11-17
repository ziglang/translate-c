#include <stdlib.h>
#include <stdbool.h>
bool  actual_bool(void)    { return 4 - 1 < 4;}
char  char_bool_ret(void)  { return 0 || 1; }
short short_bool_ret(void) { return 0 < 1; }
int   int_bool_ret(void)   { return 1 && 1; }
long  long_bool_ret(void)  { return !(0 > 1); }
static int GLOBAL = 1;
int nested_scopes(int a, int b) {
    if (a == 1) {
        int target = 1;
        return b == target;
    } else {
        int target = 2;
        if (b == target) {
            return GLOBAL == 1;
        }
        return target == 2;
    }
}
int main(void) {
    if (!actual_bool()) abort();
    if (!char_bool_ret()) abort();
    if (!short_bool_ret()) abort();
    if (!int_bool_ret()) abort();
    if (!long_bool_ret()) abort();
    if (!nested_scopes(1, 1)) abort();
    if (nested_scopes(1, 2)) abort();
    if (!nested_scopes(0, 2)) abort();
    if (!nested_scopes(0, 3)) abort();
    return 1 != 1;
}

// run
// expect=fail
