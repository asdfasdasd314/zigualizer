const sim_mod = @import("sim.zig");

pub fn main() !void {
    const sim = sim_mod.Sim{ .window_width = 600, .window_height = 480, .window_title = "My Zig Application" };
    try sim.setup();
    try sim.run();
}
