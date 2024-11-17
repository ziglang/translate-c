#include <stdlib.h>
static int cnt = 0;
int foo() { cnt++; return 42; }
int main(int argc, char **argv) {
  short q = 3;
  signed char z0 = q?:1;
  if (z0 != 3) abort();
  int z1 = 3?:1;
  if (z1 != 3) abort();
  int z2 = foo()?:-1;
  if (z2 != 42) abort();
  if (cnt != 1) abort();
  return 0;
}

// run
// expect=fail
