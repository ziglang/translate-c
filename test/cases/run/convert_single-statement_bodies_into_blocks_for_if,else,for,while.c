#include <stdlib.h>
int foo() { return 1; }
int main(void) {
    int i = 0;
    if (i == 0) if (i == 0) if (i != 0) i = 1;
    if (i != 0) i = 1; else if (i == 0) if (i == 0) i += 1;
    for (; i < 10;) for (; i < 10;) i++;
    while (i == 100) while (i == 100) foo();
    if (0) do do "string"; while(1); while(1);
    return 0;
}

// run
// expect=fail
