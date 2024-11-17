#include <stdlib.h>
unsigned int choose[53][10];
static int hash_binary(int k)
{
    choose[0][k] = 3;
    int sum = 0;
    sum += choose[0][k];
    return sum;
}

int main() {
    int s = hash_binary(4);
    if (s != 3) abort();
    return 0;
}

// run
// expect=fail
