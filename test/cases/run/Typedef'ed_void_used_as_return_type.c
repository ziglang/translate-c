typedef void V;
V foo(V *f) {}
int main(void) {
    int x = 0;
    foo(&x);
    return 0;
}

// run
