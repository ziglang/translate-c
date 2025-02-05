typedef _Atomic(int) AtomicInt;

// translate
// target=x86_64-linux
//
// tmp.c:1:22: warning: TODO support atomic type: '_Atomic(int)'
// pub const AtomicInt = @compileError("unable to resolve typedef child type");
