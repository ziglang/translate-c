// C standard: if the expression P points either to an element of an array object or one
// past the last element of an array object, and the expression Q points to the last
// element of the same array object, the expression ((Q)+1)-(P) has the same value as
// ((Q)-(P))+1 and as -((P)-((Q)+1)), and has the value zero if the expression P points
// one past the last element of the array object, even though the expression (Q)+1
// does not point to an element of the array object
#include <stdlib.h>
#include <stddef.h>
#define SIZE 10
int main() {
    int foo[SIZE];
    int *start = &foo[0];
    int *P = start + SIZE;
    int *Q = &foo[SIZE - 1];
    if ((Q + 1) - P != 0) abort();
    if ((Q + 1) - P != (Q - P) + 1) abort();
    if ((Q + 1) - P != -(P - (Q + 1))) abort();
    return 0;
}

// run
// expect=fail
