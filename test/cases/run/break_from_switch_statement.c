#include <stdlib.h>
int switcher(int x) {
    switch (x) {
        case 0:      // no braces
            x += 1;
            break;
        case 1:      // conditional break
            if (x == 1) {
                x += 1;
                break;
            }
            x += 100;
        case 2: {    // braces with fallthrough
            x += 1;
        }
        case 3:      // fallthrough to return statement
            x += 1;
        case 42: {   // random out of order case
            x += 1;
            return x;
        }
        case 4: {    // break within braces
            x += 1;
            break;
        }
        case 5:
            x += 1;  // fallthrough to default
        default:
            x += 1;
    }
    return x;
}
int main(void) {
    int expected[] = {1, 2, 5, 5, 5, 7, 7};
    for (int i = 0; i < sizeof(expected) / sizeof(int); i++) {
        int res = switcher(i);
        if (res != expected[i]) abort();
    }
    if (switcher(42) != 43) abort();
    return 0;
}

// run
// expect=fail
