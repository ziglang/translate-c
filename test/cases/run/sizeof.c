#include <stdlib.h>
int main(int argc, char **argv) {
    char a[]="a";
    char b[3]="a";
    int c[10];
    if (sizeof("a")!=2) abort();
    if (sizeof(a)!=2) abort();
    if (sizeof(b)!=3) abort();
    if (sizeof(c)!=sizeof(int)*10) abort();
    if (__alignof("a")!=1) abort();
}

// run
