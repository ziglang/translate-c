typedef struct
{
    int i;
}
*_XPrivDisplay;
typedef struct _XDisplay Display;
#define DefaultScreen(dpy) (((_XPrivDisplay)(dpy))->default_screen)


// translate
// expect=fail
//
// pub inline fn DefaultScreen(dpy: anytype) @TypeOf(@import("std").zig.c_translation.cast(_XPrivDisplay, dpy).*.default_screen) {
//     _ = &dpy;
//     return @import("std").zig.c_translation.cast(_XPrivDisplay, dpy).*.default_screen;
// }
