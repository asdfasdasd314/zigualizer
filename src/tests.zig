const math = @import("math.zig");
const std = @import("std");

test "math tests" {
    std.testing.refAllDecls(math);
}