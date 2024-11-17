#include <stdlib.h>
int lottery(unsigned int x) {
    switch (x) {
        case 3: return 0;
        case -1: return 3;
        case 8 ... 10: return x;
        default: return -1;
    }
}
int main(int argc, char **argv) {
    if (lottery(2) != -1) abort();
    if (lottery(3) != 0) abort();
    if (lottery(-1) != 3) abort();
    if (lottery(9) != 9) abort();
    return 0;
}

// run
// expect=fail
