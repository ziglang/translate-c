enum A { A0, A1=0xFFFFFFFF };
enum B { B0=-1, B1=0xFFFFFFFF };
enum C { C0=-1, C1=0 };
enum D { D0, D1=0xFFFFFFFFFFL };
enum E { E0=-1, E1=0xFFFFFFFFFFL };
int main(void) {
   signed char a0 = A0, a1 = A1;
   signed char b0 = B0, b1 = B1;
   signed char c0 = C0, c1 = C1;
   signed char d0 = D0, d1 = D1;
   signed char e0 = E0, e1 = E1;
   return 0;
}

// run
