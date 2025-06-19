# Translate-C

A Zig package for translating C code into Zig code, intended to replace `@cImport` and `zig translate-c`.

## Usage

Add `translate-c` to your `build.zig.zon` with this command:

```sh-session
$ zig fetch --save git+https://github.com/ziglang/translate-c
info: resolved to commit 1aa9ec052415feeaa0494190ae35a94849a24399
```

Then, within your `build.zig`, write something like this:

```zig
// An abstraction to make using translate-c as simple as possible.
const Translator = @import("translate_c").Translator;

// You *can* pass `target` and/or `optimize` in the options struct here, but it's typically
// not necessary. You usually want to build for the host target, which is the default.
const translate_c = b.dependency("translate_c", .{});

const t: Translator = .init(translate_c, .{
    .c_source_file = b.path("to_translate.h"),
    .target = target,
    .optimize = optimize,
});
// If you want, you can now call methods on `Translator` to add include paths (etc).

// Depend on the translated C code as a Zig module.
some_module.addImport("translated", t.mod);
// ...or, if you want to, just use the output file directly.
const translated_to_zig: LazyPath = t.output_file;
```

For a more complete usage, take a look at the [Examples](#examples).

## Examples

This repository contains a few examples in the `examples/` directory. You can test that all of the examples
work by running `zig build all` in that directory.

Within a specific example's directory, run `zig build test` to test that example. Most also have a step
called `run` or similar which you can use to run the compiled program without hiding stdout.

- [import header](examples/import_header/build.zig)
- [compile c](examples/compile_c/build.zig)
- [use static library](examples/use_static_lib/build.zig)
