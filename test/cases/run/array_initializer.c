#include <stdlib.h>
int main(int argc, char **argv) {
    int a0[4] = {1};
    int a1[4] = {1,2,3,4};
    int s0 = 0, s1 = 0;
    for (int i = 0; i < 4; i++) {
        s0 += a0[i];
        s1 += a1[i];
    }
    if (s0 != 1) abort();
    if (s1 != 10) abort();
}

// run
