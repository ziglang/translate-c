#include <stdlib.h>
static int hash_binary(int k)
{
    unsigned int choose[3] = {1, 2, 3};
    int sum = -2;
    int prev = sum + choose[k];
    if (prev != 0) abort();
    return sum + prev;
}

int main() {
    int x = hash_binary(1);
    if (x != -2) abort();
    return 0;
}

// run
