#include <stdlib.h>
#include <stdint.h>
typedef int16_t  __v8hi __attribute__((__vector_size__(16)));
int main(int argc, char**argv) {
    __v8hi uninitialized;
    __v8hi empty_init = {};
    for (int i = 0; i < 8; i++) {
        if (empty_init[i] != 0) abort();
    }
    __v8hi partial_init = {0, 1, 2, 3};

    __v8hi a = {0, 1, 2, 3, 4, 5, 6, 7};
    __v8hi b = (__v8hi) {100, 200, 300, 400, 500, 600, 700, 800};

    __v8hi sum = a + b;
    for (int i = 0; i < 8; i++) {
        if (sum[i] != a[i] + b[i]) abort();
    }
    return 0;
}

// run
// skip_vector_index=true
