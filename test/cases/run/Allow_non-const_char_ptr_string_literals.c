#include <stdlib.h>
int func(char *x) { return x[0]; }
struct S { char *member; };
struct S global_struct = { .member = "global" };
char *g = "global";
int main(void) {
   if (g[0] != 'g') abort();
   if (global_struct.member[0] != 'g') abort();
   char *string = "hello";
   if (string[0] != 'h') abort();
   struct S s = {.member = "hello"};
   if (s.member[0] != 'h') abort();
   if (func("foo") != 'f') abort();
   return 0;
}

// run
// expect=fail
