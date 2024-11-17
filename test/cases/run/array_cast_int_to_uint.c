#include <stdlib.h>
static unsigned int hash_binary(int k)
{
    int choose[3] = {-1, -2, 3};
    unsigned int sum = 2;
    sum += choose[k];
    return sum;
}

int main() {
    unsigned int x = hash_binary(1);
    if (x != 0) abort();
    return 0;
}

// run
// expect=fail
