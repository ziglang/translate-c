__asm__(".globl func\n\t"
        ".type func, @function\n\t"
        "func:\n\t"
        ".cfi_startproc\n\t"
        "movl $42, %eax\n\t"
        "ret\n\t"
        ".cfi_endproc");

// translate
// expect=fail
//
// comptime {
//     asm (".globl func\n\t.type func, @function\n\tfunc:\n\t.cfi_startproc\n\tmovl $42, %eax\n\tret\n\t.cfi_endproc");
// }
