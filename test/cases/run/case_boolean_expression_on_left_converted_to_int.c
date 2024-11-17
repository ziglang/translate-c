#include <stdlib.h>
int main(int argc, char **argv) {
  int value = 8 == 9 | 1 + 2 * 3 + 4 * 5 + 6 << 7;
  if (value != 4224) abort();
  return 0;
}

// run
// expect=fail
