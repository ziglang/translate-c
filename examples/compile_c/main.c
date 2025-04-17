#include <stdio.h>

#ifdef __TRANSLATE_C__
# define LANGUAGE "Zig"
#else
# define LANGUAGE "C"
#endif

int main(int argc, const char *argv[]) {
    printf("Hello from my %s program!\n", LANGUAGE);
    return 0;
}
