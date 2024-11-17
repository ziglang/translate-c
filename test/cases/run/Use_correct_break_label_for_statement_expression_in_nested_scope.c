#include <stdlib.h>
int main(void) {
    int x = ({1, ({2; 3;});});
    if (x != 3) abort();
    return 0;
}

// run
// expect=fail
