// For running the tests
const std = @import("std");
const math = @import("math.zig");

test "math tests" {
    std.testing.refAllDecls(math);
}
