#include <stdlib.h>
#include <stdint.h>
typedef int16_t  __v8hi __attribute__((__vector_size__(16)));
typedef uint16_t __v8hu __attribute__((__vector_size__(16)));
int main(int argc, char**argv) {
    __v8hi signed_vector = { 1, 2, 3, 4, -1, -2, -3,-4};
    __v8hu unsigned_vector = __builtin_convertvector(signed_vector, __v8hu);

    for (int i = 0; i < 8; i++) {
        if (unsigned_vector[i] != (uint16_t)signed_vector[i]) abort();
    }
    return 0;
}

// run
