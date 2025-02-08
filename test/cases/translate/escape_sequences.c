const char *escapes() {
char a = '\'',
    b = '\\',
    c = '\a',
    d = '\b',
    e = '\f',
    f = '\n',
    g = '\r',
    h = '\t',
    i = '\v',
    j = '\0',
    k = '\"';
    return "\'\\\a\b\f\n\r\t\v\0\"";
}


// translate
//
// pub export fn escapes() [*c]const u8 {
//     var a: u8 = '\'';
//     _ = &a;
//     var b: u8 = '\\';
//     _ = &b;
//     var c: u8 = '\x07';
//     _ = &c;
//     var d: u8 = '\x08';
//     _ = &d;
//     var e: u8 = '\x0c';
//     _ = &e;
//     var f: u8 = '\n';
//     _ = &f;
//     var g: u8 = '\r';
//     _ = &g;
//     var h: u8 = '\t';
//     _ = &h;
//     var i: u8 = '\x0b';
//     _ = &i;
//     var j: u8 = '\x00';
//     _ = &j;
//     var k: u8 = '"';
//     _ = &k;
//     return "'\\\x07\x08\x0c\n\r\t\x0b\x00\"";
// }
