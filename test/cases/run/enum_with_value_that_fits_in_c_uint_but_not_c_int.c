#include <stdlib.h>
enum my_enum {
    FORCE_UINT = 0xffffffff
};
int main(void) {
    if(FORCE_UINT != 0xffffffff) abort();
}

// run
