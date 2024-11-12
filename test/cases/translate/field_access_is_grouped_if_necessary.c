unsigned long foo(unsigned long x) {
    return ((union{unsigned long _x}){x})._x;
}

// translate
// expect=fail
//
// pub export fn foo(arg_x: c_ulong) c_ulong {
//     var x = arg_x;
//     _ = &x;
//     const union_unnamed_1 = extern union {
//         _x: c_ulong,
//     };
//     _ = &union_unnamed_1;
//     return (union_unnamed_1{
//         ._x = x,
//     })._x;
// }
