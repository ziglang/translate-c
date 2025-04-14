#include <stdlib.h>
union U { int x; double y; };
union U u;
int main(void) {
    if (u.x != 0) abort();
    return 0;
}

// run
