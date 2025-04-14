#include <stdlib.h>
static int FOO = 42;
typedef typeof(FOO) foo_type;
typeof(foo_type) myfunc(typeof(FOO) x) { return (typeof(FOO)) x; }
int main(void) {
    int x = FOO;
    typeof(x) y = x;
    foo_type z = y;
    if (x != y) abort();
    if (myfunc(z) != x) abort();

    const char *my_string = "bar";
    typeof (typeof (my_string)[4]) string_arr = {"a","b","c","d"};
    if (string_arr[0][0] != 'a' || string_arr[3][0] != 'd') abort();
    return 0;
}

// run
