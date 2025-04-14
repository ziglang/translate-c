#include <stdlib.h>
int main(int argc, char **argv) {
  int value = (8 == 9) < 3;
  if (value == 0) abort();
  return 0;
}

// run
