int abort(void); // TODO use #include <stdlib.h>
int main(void) {
   int int1 = 1;
   int int2 = 2;
   int int100000000 = 100000000;
   signed short foo;
   signed short val = -1;
   foo = (val += int1); if (foo != 0) abort();
   foo = (val -= int1); if (foo != -1) abort();
   foo = (val *= int2); if (foo != -2) abort();
   foo = (val /= int2); if (foo != -1) abort();
   foo = (val %= int2); if (foo != -1) abort();
   foo = (val <<= int1); if (foo != -2) abort();
   foo = (val >>= int1); if (foo != -1) abort();
   foo = (val += int100000000);    // compile error if @truncate() not inserted
   unsigned short ufoo;
   unsigned short uval = 1;
   ufoo = (uval += int1); if (ufoo != 2) abort();
   ufoo = (uval -= int1); if (ufoo != 1) abort();
   ufoo = (uval *= int2); if (ufoo != 2) abort();
   ufoo = (uval /= int2); if (ufoo != 1) abort();
   ufoo = (uval %= int2); if (ufoo != 1) abort();
   ufoo = (uval <<= int1); if (ufoo != 2) abort();
   ufoo = (uval >>= int1); if (ufoo != 1) abort();
   ufoo = (uval += int100000000);  // compile error if @truncate() not inserted
}

// run
