const std = @import("std");
const rl = @import("raylib");
const sim_mod = @import("sim.zig");
const geometry = @import("geometry.zig");
const render_system = @import("render_system.zig");

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

    // Create polygon points
    var polygon_points = try alloc.alloc([]rl.Vector3, 1);
    defer {
        for (polygon_points) |points| {
            alloc.free(points);
        }
        alloc.free(polygon_points);
    }

    // Create a pentagon
    polygon_points[0] = try alloc.alloc(rl.Vector3, 5);
    polygon_points[0][0] = rl.Vector3{ .x = 0, .y = 0, .z = 2 };
    polygon_points[0][1] = rl.Vector3{ .x = 1, .y = 0, .z = 2 };
    polygon_points[0][2] = rl.Vector3{ .x = 1.5, .y = 0.5, .z = 2 };
    polygon_points[0][3] = rl.Vector3{ .x = 0.5, .y = 1, .z = 2 };
    polygon_points[0][4] = rl.Vector3{ .x = -0.5, .y = 0.5, .z = 2 };

    // Create polygons
    var polygons = try alloc.alloc(geometry.Polygon, 1);
    defer alloc.free(polygons);
    polygons[0] = geometry.Polygon{ .points = polygon_points[0], .color = rl.Color.red };

    // Create a cube
    const cube = try alloc.create(geometry.Cube);
    cube.* = geometry.Cube{ .p0 = rl.Vector3{ .x = 0, .y = 0, .z = 0 }, .width = 1, .height = 1, .length = 1, .color = rl.Color.blue };
    defer alloc.destroy(cube);

    // Create renderables
    var renderables = try alloc.alloc(render_system.Renderable, polygons.len + 1);
    defer alloc.free(renderables);

    for (polygons, 0..) |*polygon, i| {
        renderables[i] = render_system.Renderable{ .polygon = polygon };
    }

    renderables[polygons.len] = render_system.Renderable{ .cube = cube };
    var sim = try sim_mod.Sim.init(
        &alloc,
        window_height,
        window_width,
        movement_speed,
        camera_sensitivity,
        renderables,
    );
    defer sim.deinit();

    try sim.run();
}
