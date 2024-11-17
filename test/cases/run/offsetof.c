#include <stddef.h>
#include <stdlib.h>
#define container_of(ptr, type, member) ({                      \
        const typeof( ((type *)0)->member ) *__mptr = (ptr);    \
        (type *)( (char *)__mptr - offsetof(type,member) );})
typedef struct {
    int i;
    struct { int x; char y; int z; } s;
    float f;
} container;
int main(void) {
    if (offsetof(container, i) != 0) abort();
    if (offsetof(container, s) <= offsetof(container, i)) abort();
    if (offsetof(container, f) <= offsetof(container, s)) abort();

    container my_container;
    typeof(my_container.s) *inner_member_pointer = &my_container.s;
    float *float_member_pointer = &my_container.f;
    int *anon_member_pointer = &my_container.s.z;
    container *my_container_p;

    my_container_p = container_of(inner_member_pointer, container, s);
    if (my_container_p != &my_container) abort();

    my_container_p = container_of(float_member_pointer, container, f);
    if (my_container_p != &my_container) abort();

    if (container_of(anon_member_pointer, typeof(my_container.s), z) != inner_member_pointer) abort();
    return 0;
}

// run
// expect=fail
