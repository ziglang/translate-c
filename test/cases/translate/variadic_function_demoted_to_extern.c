int foo(int bar, ...) {
    return 1;
}

// translate
// expect=fail
//
// warning: TODO unable to translate variadic function, demoted to extern
// pub extern fn foo(bar: c_int, ...) c_int;
