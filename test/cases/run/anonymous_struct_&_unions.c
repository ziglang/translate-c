#include <stdlib.h>
#include <stdint.h>
static struct { struct { uint16_t x, y; }; } x = { 1 };
static struct { union { uint32_t x; uint8_t y; }; } y = { 0x55AA55AA };
int main(int argc, char **argv) {
    if (x.x != 1) abort();
    if (x.y != 0) abort();
    if (y.x != 0x55AA55AA) abort();
    if (y.y != 0xAA) abort();
    return 0;
}

// run
// expect=fail
