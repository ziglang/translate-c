#include <stdlib.h>
int main(void) {
   signed short val = -1;
   val += 1; if (val != 0) abort();
   val -= 1; if (val != -1) abort();
   val *= 2; if (val != -2) abort();
   val /= 2; if (val != -1) abort();
   val %= 2; if (val != -1) abort();
   val <<= 1; if (val != -2) abort();
   val >>= 1; if (val != -1) abort();
   val += 100000000;       // compile error if @truncate() not inserted
   unsigned short uval = 1;
   uval += 1; if (uval != 2) abort();
   uval -= 1; if (uval != 1) abort();
   uval *= 2; if (uval != 2) abort();
   uval /= 2; if (uval != 1) abort();
   uval %= 2; if (uval != 1) abort();
   uval <<= 1; if (uval != 2) abort();
   uval >>= 1; if (uval != 1) abort();
   uval += 100000000;      // compile error if @truncate() not inserted
}

// run
// expect=fail
