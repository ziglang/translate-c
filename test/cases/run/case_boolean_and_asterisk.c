#include <stdlib.h>
int main(int argc, char **argv) {
  int value = (8 == 9) * 3;
  int value2 = 3 * (9 == 9);
  if (value != 0) abort();
  if (value2 == 0) abort();
  return 0;
}

// run
// expect=fail
