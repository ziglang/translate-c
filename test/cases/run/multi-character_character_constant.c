#include <stdlib.h>
int main(void) {
    int foo = 'abcd';
    switch (foo) {
        case 'abcd': break;
        default: abort();
    }
    return 0;
}

// run
