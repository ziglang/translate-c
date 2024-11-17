#include <stdlib.h>
int main(void) {
   signed short foo;
   signed short val = -1;
   foo = (val += 1); if (foo != 0) abort();
   foo = (val -= 1); if (foo != -1) abort();
   foo = (val *= 2); if (foo != -2) abort();
   foo = (val /= 2); if (foo != -1) abort();
   foo = (val %= 2); if (foo != -1) abort();
   foo = (val <<= 1); if (foo != -2) abort();
   foo = (val >>= 1); if (foo != -1) abort();
   foo = (val += 100000000);    // compile error if @truncate() not inserted
   unsigned short ufoo;
   unsigned short uval = 1;
   ufoo = (uval += 1); if (ufoo != 2) abort();
   ufoo = (uval -= 1); if (ufoo != 1) abort();
   ufoo = (uval *= 2); if (ufoo != 2) abort();
   ufoo = (uval /= 2); if (ufoo != 1) abort();
   ufoo = (uval %= 2); if (ufoo != 1) abort();
   ufoo = (uval <<= 1); if (ufoo != 2) abort();
   ufoo = (uval >>= 1); if (ufoo != 1) abort();
   ufoo = (uval += 100000000);  // compile error if @truncate() not inserted
}

// run
// expect=fail
