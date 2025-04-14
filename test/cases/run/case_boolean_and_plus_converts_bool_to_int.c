#include <stdlib.h>
int main(int argc, char **argv) {
  int value = (8 == 9) + 3;
  int value2 = 3 + (8 == 9);
  if (value != value2) abort();
  return 0;
}

// run
