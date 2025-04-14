#include <stdint.h>
#include <stdlib.h>
#define TEST_NEGATIVE(type) { type x = -1; if (ptr[x] != 42) abort(); }
#define TEST_UNSIGNED(type) { type x = 2; if (arr[x] != 42) abort(); }
int main(void) {
    int arr[] = {40, 41, 42, 43};
    int *ptr = arr + 3;
    if (ptr[-1] != 42) abort();
    TEST_NEGATIVE(int);
    TEST_NEGATIVE(long);
    TEST_NEGATIVE(long long);
    TEST_NEGATIVE(int64_t);
    TEST_NEGATIVE(__int128);
    TEST_UNSIGNED(unsigned);
    TEST_UNSIGNED(unsigned long);
    TEST_UNSIGNED(unsigned long long);
    TEST_UNSIGNED(uint64_t);
    TEST_UNSIGNED(size_t);
    TEST_UNSIGNED(unsigned __int128);
    return 0;
}

// run
