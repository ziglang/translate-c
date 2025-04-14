#include <stdlib.h>
int sign(int v) {
    return -(v < 0);
}
int main(void) {
    if (sign(-5) != -1) abort();
    if (sign(5) != 0) abort();
    if (sign(0) != 0) abort();
    return 0;
}

// run
