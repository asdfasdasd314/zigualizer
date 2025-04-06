const std = @import("std");
const rl = @import("raylib");
const sim_mod = @import("sim.zig");
const math = @import("math.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var alloc = gpa.allocator();
    // var sim = try sim_mod.Sim.init(&alloc, 480, 680, 10, 0.1);
    // try sim.run();
    // sim.deinit();

    // Allocate space for contents
    const contents = try alloc.alloc([]f32, 5);
    defer alloc.free(contents);

    for (0..5) |i| {
        contents[i] = try alloc.alloc(f32, 5);
    }

    defer {
        for (0..5) |i| {
            alloc.free(contents[i]);
        }
    }

    // Row 0
    contents[0][0] = 0.732;
    contents[0][1] = 0.143;
    contents[0][2] = 0.881;
    contents[0][3] = 0.550;
    contents[0][4] = 0.321;

    // Row 1
    contents[1][0] = 0.620;
    contents[1][1] = 0.458;
    contents[1][2] = 0.278;
    contents[1][3] = 0.716;
    contents[1][4] = 0.035;

    // Row 2
    contents[2][0] = 0.987;
    contents[2][1] = 0.104;
    contents[2][2] = 0.391;
    contents[2][3] = 0.204;
    contents[2][4] = 0.674;

    // Row 3
    contents[3][0] = 0.456;
    contents[3][1] = 0.791;
    contents[3][2] = 0.203;
    contents[3][3] = 0.918;
    contents[3][4] = 0.382;

    // Row 4
    contents[4][0] = 0.217;
    contents[4][1] = 0.660;
    contents[4][2] = 0.330;
    contents[4][3] = 0.889;
    contents[4][4] = 0.078;

    var mat = try math.Matrix.init(&alloc, contents);
    std.debug.print("Matrix: {}\n", .{mat});

    const det = try mat.determinant();
    std.debug.print("Determinant: {}\n", .{det.?});
}
