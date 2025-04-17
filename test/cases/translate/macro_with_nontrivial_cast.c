#define MAP_FAILED ((void *) -1)
typedef long long LONG_PTR;
#define INVALID_HANDLE_VALUE ((void *)(LONG_PTR)-1)

// translate
//
// pub const MAP_FAILED = __helpers.cast(?*anyopaque, -@as(c_int, 1));
// pub const INVALID_HANDLE_VALUE = __helpers.cast(?*anyopaque, __helpers.cast(LONG_PTR, -@as(c_int, 1)));
