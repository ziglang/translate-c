typedef struct
{
    int i;
}
*_XPrivDisplay;
typedef struct _XDisplay Display;
#define DefaultScreen(dpy) (((_XPrivDisplay)(dpy))->default_screen)


// translate
//
// pub inline fn DefaultScreen(dpy: anytype) @TypeOf(__helpers.cast(_XPrivDisplay, dpy).*.default_screen) {
//     _ = &dpy;
//     return __helpers.cast(_XPrivDisplay, dpy).*.default_screen;
// }
