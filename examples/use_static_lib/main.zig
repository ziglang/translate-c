const foo = @import("foo");
pub fn main() void {
    const result = foo.foo_add(1, 2);
    foo.foo_print("1 + 2 = %d\n", result);
}
