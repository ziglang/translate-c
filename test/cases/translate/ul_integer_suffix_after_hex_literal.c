#define SDL_INIT_VIDEO 0x00000020ul  /**< SDL_INIT_VIDEO implies SDL_INIT_EVENTS */

// translate
// expect=fail
//
// pub const SDL_INIT_VIDEO = @as(c_ulong, 0x00000020);
