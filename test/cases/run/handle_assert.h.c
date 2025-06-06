#include <assert.h>
int main() {
    int x = 1;
    int *xp = &x;
    assert(1);
    assert(x != 0);
    assert(xp);
    assert(*xp);
    return 0;
}

// run
