const std = @import("std");
const rl = @import("raylib");
const sim_mod = @import("sim.zig");
const math = @import("math.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const result = gpa.deinit();
        if (result == .leak) {
            std.debug.print("Memory leaks detected!\n", .{});
        }
    }
    var alloc = gpa.allocator();

    const window_width: i32 = 1280;
    const window_height: i32 = 720;
    const movement_speed: f32 = 5.0;
    const camera_sensitivity: f32 = 0.1;

    var sim = try sim_mod.Sim.init(&alloc, window_height, window_width, movement_speed, camera_sensitivity);
    defer sim.deinit();

    try sim.run();
}
