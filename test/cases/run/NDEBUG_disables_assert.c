#define NDEBUG
#include <assert.h>
int main() {
    assert(0);
    assert(NULL);
    return 0;
}

// run
// expect=fail
