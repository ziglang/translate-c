# Python Extension Example

This example demonstrates how to use translate-c to create a minimal Python extension in Zig.

## What it does

This example shows how to:
1. Use translate-c to parse Python.h header file
2. Create a Python extension module in Zig
3. Export functions that can be called from Python
4. Handle Python C API calls using the translated bindings

## Building

```bash
zig build install
```

This creates a shared library `zig-out/lib/libzig_ext.so` which can be imported as a Python extension.

## Testing

```bash
# Test the build
zig build install

# Test importing in Python (from the project directory)
python3 -c "import sys; sys.path.insert(0, 'zig-out/lib'); import zig_ext; print('Successfully imported zig_ext!'); print('zig_ext.get_greeting():', zig_ext.get_greeting()); print('zig_ext.add_numbers(5, 3):', zig_ext.add_numbers(5, 3))"
```

## Usage

After building, you can import the extension in Python:

```python
import sys
sys.path.insert(0, 'zig-out/lib')  # Add the library path to Python path
import zig_ext

# Add two numbers
result = zig_ext.add_numbers(5, 3)
print(f"zig_ext.add_numbers(5, 3) = {result}")  # Output: 8

# Get a greeting
greeting = zig_ext.get_greeting()
print(greeting)  # Output: Hello from Zig-based Python extension!
```

The extension is named `zig_ext` and provides two functions:
- `zig_ext.get_greeting()` - Returns a greeting string
- `zig_ext.add_numbers(a, b)` - Adds two integers and returns the result

## Files

- `build.zig` - Build script that sets up translate-c for Python.h
- `extension.zig` - Zig implementation of the Python extension
- `README.md` - This file

## How it works

1. The build script uses `translate-c` to translate Python.h directly into Zig bindings
2. The `extension.zig` file imports these bindings as a module named "python"
3. It then implements Python C API functions using the translated bindings
4. The module exports two functions: `add_numbers` and `get_greeting`
5. These can be called from Python just like any other Python module