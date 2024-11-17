#include <stdlib.h>
int main() {
    int count = 0;
    for (int x = 0; x < 2; x++)
        for (int x = 0; x < 2; x++)
            count++;

    if (count != 4) abort();
    return 0;
}

// run
// expect=fail
