#include <stdarg.h>
#include <stdio.h>
void foo_print(const char *format, ...) {
    va_list ap;
    va_start(ap, format);
    (void)vprintf(format, ap);
    va_end(ap);
}
