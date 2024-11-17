// Use the "segment,section" format to make this test pass when
// targeting the mach-o binary format
__attribute__ ((__section__("NEAR,.data")))
extern char my_array[16];
__attribute__ ((__section__("NEAR,.data")))
void my_fn(void) { }

// translate
// expect=fail
//
// pub extern var my_array: [16]u8 linksection("NEAR,.data");
// pub export fn my_fn() linksection("NEAR,.data") void {}
