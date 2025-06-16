#include <stdlib.h>
static int hash_binary(int k)
{
    unsigned int choose[1][1] = {{3}};
    int sum = -1;
    int prev = 0;
    prev = sum += choose[0][0];
    if (sum != 2) abort();
    return sum + prev;
}

int main() {
    int x = hash_binary(4);
    if (x != 4) abort();
    return 0;
}

// run
