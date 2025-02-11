void foo() {
 typedef union {
  int A;
  int B;
  int C;
 } Foo;
 Foo a = {0};
 {
  typedef union {
   int A;
   int B;
   int C;
  } Foo;
  Foo a = {0};
 }
}

// translate
//
// pub export fn foo() void {
//     const union_unnamed_1 = extern union {
//         A: c_int,
//         B: c_int,
//         C: c_int,
//     };
//     _ = &union_unnamed_1;
//     const Foo = union_unnamed_1;
//     _ = &Foo;
//     var a: Foo = Foo{
//         .A = 0,
//     };
//     _ = &a;
//     {
//         const union_unnamed_2 = extern union {
//             A: c_int,
//             B: c_int,
//             C: c_int,
//         };
//         _ = &union_unnamed_2;
//         const Foo_1 = union_unnamed_2;
//         _ = &Foo_1;
//         var a_2: Foo_1 = Foo_1{
//             .A = 0,
//         };
//         _ = &a_2;
//     }
// }
