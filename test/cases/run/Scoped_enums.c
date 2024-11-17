#include <stdlib.h>
int main(void) {
   enum Foo { A, B, C };
   enum Foo a = B;
   if (a != B) abort();
   if (a != 1) abort();
   {
      enum Foo { A = 5, B = 6, C = 7 };
      enum Foo a = B;
      if (a != B) abort();
      if (a != 6) abort();
   }
   if (a != B) abort();
   if (a != 1) abort();
}

// run
// expect=fail
