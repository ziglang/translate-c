#include <stdlib.h>
#include <stdint.h>
typedef int16_t  __v4hi __attribute__((__vector_size__(8)));
typedef int16_t  __v8hi __attribute__((__vector_size__(16)));
int main(int argc, char**argv) {
    __v8hi v8_a = {0, 1, 2, 3, 4, 5, 6, 7};
    __v8hi v8_b = {100, 200, 300, 400, 500, 600, 700, 800};
    __v8hi shuffled = __builtin_shufflevector(v8_a, v8_b, 0, 1, 2, 3, 8, 9, 10, 11);
    for (int i = 0; i < 8; i++) {
        if (i < 4) {
            if (shuffled[i] != v8_a[i]) abort();
        } else {
            if (shuffled[i] != v8_b[i - 4]) abort();
        }
    }
    shuffled = __builtin_shufflevector(
        (__v8hi) {-1, -1, -1, -1, -1, -1, -1, -1},
        (__v8hi) {42, 42, 42, 42, 42, 42, 42, 42},
        0, 1, 2, 3, 8, 9, 10, 11
    );
    for (int i = 0; i < 8; i++) {
        if (i < 4) {
            if (shuffled[i] != -1) abort();
        } else {
            if (shuffled[i] != 42) abort();
        }
    }
    __v4hi shuffled_to_fewer_elements = __builtin_shufflevector(v8_a, v8_b, 0, 1, 8, 9);
    for (int i = 0; i < 4; i++) {
        if (i < 2) {
            if (shuffled_to_fewer_elements[i] != v8_a[i]) abort();
        } else {
            if (shuffled_to_fewer_elements[i] != v8_b[i - 2]) abort();
        }
    }
    __v4hi v4_a = {0, 1, 2, 3};
    __v4hi v4_b = {100, 200, 300, 400};
    __v8hi shuffled_to_more_elements = __builtin_shufflevector(v4_a, v4_b, 0, 1, 2, 3, 4, 5, 6, 7);
    for (int i = 0; i < 4; i++) {
        if (shuffled_to_more_elements[i] != v4_a[i]) abort();
        if (shuffled_to_more_elements[i + 4] != v4_b[i]) abort();
    }
    return 0;
}

// run
