#include <stdlib.h>
int main(int argc, char **argv) {
  int value = 1 + 2 * 3 + 4 * 5 + 6 << 7 | 8 == 9;
  if (value != 4224) abort();
  return 0;
}

// run
// expect=fail
