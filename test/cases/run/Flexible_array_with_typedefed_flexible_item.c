#include <stdlib.h>
#include <assert.h>
typedef int MARKER[0];
typedef struct { int x; MARKER y; } Flexible;
#define SIZE 10
int main(void) {
    Flexible *flex = malloc(sizeof(Flexible) + SIZE * sizeof(int));
    for (int i = 0; i < SIZE; i++) {
        flex->y[i] = i;
    }
    for (int i = 0; i < SIZE; i++) {
        assert(flex->y[i] == i);
    }
    return 0;
}

// run
