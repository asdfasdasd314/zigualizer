const std = @import("std");
const rl = @import("raylib");
const sim_mod = @import("sim.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var alloc = gpa.allocator();
    var sim = try sim_mod.Sim.init(&alloc, 480, 680, 10, 0.1);
    try sim.run();
}