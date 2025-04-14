#include <stdlib.h>
int main(void) {
    int arr[] = {40, 41, 42, 43};
    if ((arr + 1)[1] != 42) abort();
    return 0;
}

// run
