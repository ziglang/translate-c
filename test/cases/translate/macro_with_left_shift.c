#define REDISMODULE_READ (1<<0)

// translate
// expect=fail
//
// pub const REDISMODULE_READ = @as(c_int, 1) << @as(c_int, 0);
