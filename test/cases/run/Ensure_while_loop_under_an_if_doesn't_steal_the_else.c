#include <stdio.h>
void doWork(int id) { }
int reallyDelete(int id) { printf("deleted %d\n", id); return 1; }
int process(int id, int n, int delete) {
    if(!delete)
        while(n-- > 0) doWork(id);
    else
        return reallyDelete(id);
    return 0;
}
int main(void) {
    process(99, 3, 0);
    return 0;
}

// run
// skip_windows=true
