#define _NO_CRT_STDIO_INLINE 1
#include <stdint.h>
#include <stdlib.h>
struct s {uint8_t x,y;
          uint32_t z;} __attribute__((packed)) s0 = {1, 2};
int main() {
  /* sizeof nor offsetof currently supported */
  if (((intptr_t)&s0.z - (intptr_t)&s0.x) != 2) abort();
  return 0;
}

// run
