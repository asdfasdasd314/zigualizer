const sim_mod = @import("sim.zig");

pub fn main() !void {
    var sim = sim_mod.Sim {
        .window_height = 480,
        .window_width = 600,
        .window_title = "Zigualizer", 
    };
    try sim.run();
}