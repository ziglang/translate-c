#include <stdlib.h>
int bar(int a) {
    extern int abs(int);
    return a;
}
int main(int argc, char **argv) {
    if (abs(-3) != 3) abort();
    return 0;
}

// run
