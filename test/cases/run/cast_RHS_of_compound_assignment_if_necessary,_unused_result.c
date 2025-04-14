int abort(void); // TODO use #include <stdlib.h>
int main(void) {
   int int1 = 1;
   int int2 = 2;
   int int100000000 = 100000000;
   signed short val = -1;
   val += int1; if (val != 0) abort();
   val -= int1; if (val != -1) abort();
   val *= int2; if (val != -2) abort();
   val /= int2; if (val != -1) abort();
   val %= int2; if (val != -1) abort();
   val <<= int1; if (val != -2) abort();
   val >>= int1; if (val != -1) abort();
   val += int100000000;       // compile error if @truncate() not inserted
   unsigned short uval = 1;
   uval += int1; if (uval != 2) abort();
   uval -= int1; if (uval != 1) abort();
   uval *= int2; if (uval != 2) abort();
   uval /= int2; if (uval != 1) abort();
   uval %= int2; if (uval != 1) abort();
   uval <<= int1; if (uval != 2) abort();
   uval >>= int1; if (uval != 1) abort();
   uval += int100000000;      // compile error if @truncate() not inserted
}

// run
