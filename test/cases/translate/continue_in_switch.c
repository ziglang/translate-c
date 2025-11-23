int entry(int i) {
    int res = i;
    while (1) switch (res) {
        case 0:
            res += 1;
        case 1:
            continue;
        case 2: {
            continue;
        }
        case 3:
            if (res == 42) return - 1;
            res = 42;
            continue;
        case 4:
            return 1;
        case 5:
            res = 10;
        default:
            break;
    };
    return res;
}

// translate
//
// pub export fn entry(arg_i: c_int) c_int {
//     var i = arg_i;
//     _ = &i;
//     var res: c_int = i;
//     _ = &res;
//     while (true) {
//         while (true) {
//             switch (res) {
//                 @as(c_int, 0) => {
//                     res += 1;
//                     continue;
//                 },
//                 @as(c_int, 1) => {
//                     continue;
//                 },
//                 @as(c_int, 2) => {
//                     {
//                         continue;
//                     }
//                 },
//                 @as(c_int, 3) => {
//                     if (res == @as(c_int, 42)) return -@as(c_int, 1);
//                     res = 42;
//                     continue;
//                 },
//                 @as(c_int, 4) => {
//                     return 1;
//                 },
//                 @as(c_int, 5) => {
//                     res = 10;
//                     break;
//                 },
//                 else => {
//                     break;
//                 },
//             }
//             break;
//         }
//     }
//     return res;
// }
