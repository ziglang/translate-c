void foo() {
	struct Foo {
		int A;
		int B;
		int C;
	};
	struct Foo a = {0};
	{
		struct Foo {
			int A;
			int B;
			int C;
		};
		struct Foo a = {0};
	}
}

// translate
//
// pub export fn foo() void {
//     const struct_Foo = extern struct {
//         A: c_int = 0,
//         B: c_int = 0,
//         C: c_int = 0,
//     };
//     _ = &struct_Foo;
//     var a: struct_Foo = struct_Foo{
//         .A = 0,
//         .B = 0,
//         .C = 0,
//     };
//     _ = &a;
//     {
//         const struct_Foo_1 = extern struct {
//             A: c_int = 0,
//             B: c_int = 0,
//             C: c_int = 0,
//         };
//         _ = &struct_Foo_1;
//         var a_2: struct_Foo_1 = struct_Foo_1{
//             .A = 0,
//             .B = 0,
//             .C = 0,
//         };
//         _ = &a_2;
//     }
// }
