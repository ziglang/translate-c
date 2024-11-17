#include <stdlib.h>
int main(int argc, char **argv) {
    char data[3] = {'a','b','c'};
    if (2[data] != data[2]) abort();
    if ("abc"[1] != data[1]) abort();
    char *as_ptr = data;
    if (2[as_ptr] != as_ptr[2]) abort();
    if ("abc"[1] != as_ptr[1]) abort();
    return 0;
}

// run
// expect=fail
