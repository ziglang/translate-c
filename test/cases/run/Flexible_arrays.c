#include <stdlib.h>
#include <stdint.h>
typedef struct { char foo; int bar; } ITEM;
typedef struct { size_t count; ITEM items[]; } ITEM_LIST;
typedef struct { unsigned char count; int items[]; } INT_LIST;
#define SIZE 10
int main(void) {
    ITEM_LIST *list = malloc(sizeof(ITEM_LIST) + SIZE * sizeof(ITEM));
    for (int i = 0; i < SIZE; i++) list->items[i] = (ITEM) {.foo = i, .bar = i + 1};
    const ITEM_LIST *const c_list = list;
    for (int i = 0; i < SIZE; i++) if (c_list->items[i].foo != i || c_list->items[i].bar != i + 1) abort();
    INT_LIST *int_list = malloc(sizeof(INT_LIST) + SIZE * sizeof(int));
    for (int i = 0; i < SIZE; i++) int_list->items[i] = i;
    const INT_LIST *const c_int_list = int_list;
    const int *const ints = int_list->items;
    for (int i = 0; i < SIZE; i++) if (ints[i] != i) abort();
    return 0;
}

// run
// expect=fail
