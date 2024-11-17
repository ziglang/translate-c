void foo(int *a) {}
void bar(const int *a) {
    foo((int *)a);
}
void baz(volatile int *a) {
    foo((int *)a);
}
int main(int argc, char **argv) {
    int a = 0;
    bar((const int *)&a);
    baz((volatile int *)&a);
    return 0;
}

// run
// expect=fail
