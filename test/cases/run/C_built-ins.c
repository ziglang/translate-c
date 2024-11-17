#include <stdlib.h>
#include <limits.h>
#include <stdbool.h>
#define M_E    2.71828182845904523536
#define M_PI_2 1.57079632679489661923
bool check_clz(unsigned int pos) {
    return (__builtin_clz(1 << pos) == (8 * sizeof(unsigned int) - pos - 1));
}
int main(void) {
    if (__builtin_bswap16(0x0102) != 0x0201) abort();
    if (__builtin_bswap32(0x01020304) != 0x04030201) abort();
    if (__builtin_bswap64(0x0102030405060708) != 0x0807060504030201) abort();

    if (__builtin_signbit(0.0) != 0) abort();
    if (__builtin_signbitf(0.0f) != 0) abort();
    if (__builtin_signbit(1.0) != 0) abort();
    if (__builtin_signbitf(1.0f) != 0) abort();
    if (__builtin_signbit(-1.0) != 1) abort();
    if (__builtin_signbitf(-1.0f) != 1) abort();

    if (__builtin_popcount(0) != 0) abort();
    if (__builtin_popcount(0b1) != 1) abort();
    if (__builtin_popcount(0b11) != 2) abort();
    if (__builtin_popcount(0b1111) != 4) abort();
    if (__builtin_popcount(0b11111111) != 8) abort();

    if (__builtin_ctz(0b1) != 0) abort();
    if (__builtin_ctz(0b10) != 1) abort();
    if (__builtin_ctz(0b100) != 2) abort();
    if (__builtin_ctz(0b10000) != 4) abort();
    if (__builtin_ctz(0b100000000) != 8) abort();

    if (!check_clz(0)) abort();
    if (!check_clz(1)) abort();
    if (!check_clz(2)) abort();
    if (!check_clz(4)) abort();
    if (!check_clz(8)) abort();

    if (__builtin_sqrt(__builtin_sqrt(__builtin_sqrt(256))) != 2.0) abort();
    if (__builtin_sqrt(__builtin_sqrt(__builtin_sqrt(256.0))) != 2.0) abort();
    if (__builtin_sqrt(__builtin_sqrt(__builtin_sqrt(256.0f))) != 2.0) abort();
    if (__builtin_sqrtf(__builtin_sqrtf(__builtin_sqrtf(256.0f))) != 2.0f) abort();

    if (__builtin_sin(1.0) != -__builtin_sin(-1.0)) abort();
    if (__builtin_sinf(1.0f) != -__builtin_sinf(-1.0f)) abort();
    if (__builtin_sin(M_PI_2) != 1.0) abort();
    if (__builtin_sinf(M_PI_2) != 1.0f) abort();

    if (__builtin_cos(1.0) != __builtin_cos(-1.0)) abort();
    if (__builtin_cosf(1.0f) != __builtin_cosf(-1.0f)) abort();
    if (__builtin_cos(0.0) != 1.0) abort();
    if (__builtin_cosf(0.0f) != 1.0f) abort();

    if (__builtin_exp(0) != 1.0) abort();
    if (__builtin_fabs(__builtin_exp(1.0) - M_E) > 0.00000001) abort();
    if (__builtin_exp(0.0f) != 1.0f) abort();

    if (__builtin_exp2(0) != 1.0) abort();
    if (__builtin_exp2(4.0) != 16.0) abort();
    if (__builtin_exp2f(0.0f) != 1.0f) abort();
    if (__builtin_exp2f(4.0f) != 16.0f) abort();

    if (__builtin_log(M_E) != 1.0) abort();
    if (__builtin_log(1.0) != 0.0) abort();
    if (__builtin_logf(1.0f) != 0.0f) abort();

    if (__builtin_log2(8.0) != 3.0) abort();
    if (__builtin_log2(1.0) != 0.0) abort();
    if (__builtin_log2f(8.0f) != 3.0f) abort();
    if (__builtin_log2f(1.0f) != 0.0f) abort();

    if (__builtin_log10(1000.0) != 3.0) abort();
    if (__builtin_log10(1.0) != 0.0) abort();
    if (__builtin_log10f(1000.0f) != 3.0f) abort();
    if (__builtin_log10f(1.0f) != 0.0f) abort();

    if (__builtin_fabs(-42.0f) != 42.0) abort();
    if (__builtin_fabs(-42.0) != 42.0) abort();
    if (__builtin_fabs(-42) != 42.0) abort();
    if (__builtin_fabsf(-42.0f) != 42.0f) abort();

    if (__builtin_fabs(-42.0f) != 42.0) abort();
    if (__builtin_fabs(-42.0) != 42.0) abort();
    if (__builtin_fabs(-42) != 42.0) abort();
    if (__builtin_fabsf(-42.0f) != 42.0f) abort();

    if (__builtin_abs(42) != 42) abort();
    if (__builtin_abs(-42) != 42) abort();
    if (__builtin_abs(INT_MIN) != INT_MIN) abort();

    if (__builtin_floor(42.9) != 42.0) abort();
    if (__builtin_floor(-42.9) != -43.0) abort();
    if (__builtin_floorf(42.9f) != 42.0f) abort();
    if (__builtin_floorf(-42.9f) != -43.0f) abort();

    if (__builtin_ceil(42.9) != 43.0) abort();
    if (__builtin_ceil(-42.9) != -42) abort();
    if (__builtin_ceilf(42.9f) != 43.0f) abort();
    if (__builtin_ceilf(-42.9f) != -42.0f) abort();

    if (__builtin_trunc(42.9) != 42.0) abort();
    if (__builtin_truncf(42.9f) != 42.0f) abort();
    if (__builtin_trunc(-42.9) != -42.0) abort();
    if (__builtin_truncf(-42.9f) != -42.0f) abort();

    if (__builtin_round(0.5) != 1.0) abort();
    if (__builtin_round(-0.5) != -1.0) abort();
    if (__builtin_roundf(0.5f) != 1.0f) abort();
    if (__builtin_roundf(-0.5f) != -1.0f) abort();

    if (__builtin_strcmp("abc", "abc") != 0) abort();
    if (__builtin_strcmp("abc", "def") >= 0 ) abort();
    if (__builtin_strcmp("def", "abc") <= 0) abort();

    if (__builtin_strlen("this is a string") != 16) abort();

    char *s = malloc(6);
    __builtin_memcpy(s, "hello", 5);
    s[5] = '\0';
    if (__builtin_strlen(s) != 5) abort();

    __builtin_memset(s, 42, __builtin_strlen(s));
    if (s[0] != 42 || s[1] != 42 || s[2] != 42 || s[3] != 42 || s[4] != 42) abort();

    free(s);

    return 0;
}

// run
// expect=fail
