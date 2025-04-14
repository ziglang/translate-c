// TODO: add isnan check for long double once bitfield support is added
//       (needed for x86_64-windows-gnu)
// TODO: add isinf check for long double once std.math.isInf supports c_longdouble
#include <math.h>
#include <stdint.h>
#include <stdlib.h>
union uf { uint32_t u; float f; };
#define CHECK_NAN(STR, VAL) { \
    union uf unpack = {.f = __builtin_nanf(STR)}; \
    if (!isnan(unpack.f)) abort(); \
    if (unpack.u != VAL) abort(); \
}
int main(void) {
    float f_nan = NAN;
    if (!isnan(f_nan)) abort();
    double d_nan = NAN;
    if (!isnan(d_nan)) abort();
    CHECK_NAN("0", 0x7FC00000);
    CHECK_NAN("", 0x7FC00000);
    CHECK_NAN("1", 0x7FC00001);
    CHECK_NAN("0x7FC00000", 0x7FC00000);
    CHECK_NAN("0x7FC0000F", 0x7FC0000F);
    CHECK_NAN("0x7FC000F0", 0x7FC000F0);
    CHECK_NAN("0x7FC00F00", 0x7FC00F00);
    CHECK_NAN("0x7FC0F000", 0x7FC0F000);
    CHECK_NAN("0x7FCF0000", 0x7FCF0000);
    CHECK_NAN("0xFFFFFFFF", 0x7FFFFFFF);
    float f_inf = INFINITY;
    if (!isinf(f_inf)) abort();
    double d_inf = INFINITY;
    if (!isinf(d_inf)) abort();
    return 0;
}

// run
