void bar(void);
void baz(void);
struct foo { int x; };
void bar() {
    struct foo tmp;
}

void baz() {
    struct foo tmp;
}

int main(void) {
    bar();
    baz();
    return 0;
}

// run
