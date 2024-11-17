#include <stdlib.h>
static int cleanup_count = 0;
void clean_up(int *final_value) {
    if (*final_value != cleanup_count++) abort();
}
void doit(void) {
    int a __attribute__ ((__cleanup__(clean_up))) __attribute__ ((unused)) = 2;
    int b __attribute__ ((__cleanup__(clean_up))) __attribute__ ((unused)) = 1;
    int c __attribute__ ((__cleanup__(clean_up))) __attribute__ ((unused)) = 0;
}
int main(void) {
    doit();
    if (cleanup_count != 3) abort();
    return 0;
}

// run
// expect=fail
