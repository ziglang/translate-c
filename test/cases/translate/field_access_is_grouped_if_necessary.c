unsigned long foo(unsigned long x) {
    return ((union{unsigned long _x}){x})._x;
}

// translate
//
// pub export fn foo(arg_x: c_ulong) c_ulong {
//     var x = arg_x;
//     _ = &x;
//     const union_unnamed_1 = extern union {
//         _x: c_ulong,
//     };
//     _ = &union_unnamed_1;
//     const union_unnamed_2 = extern union {
//         _x: c_ulong,
//     };
//     _ = &union_unnamed_2;
//     return @as(union_unnamed_2, union_unnamed_2{
//         ._x = x,
//     })._x;
// }
