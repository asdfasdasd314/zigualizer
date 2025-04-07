const rl = @import("raylib");
const std = @import("std");
const render = @import("render.zig");

pub const Spectator = struct {
    allocator: *std.mem.Allocator,
    camera: *rl.Camera3D,

    camera_sensitivity: f32,
    movement_speed: f32,

    pitch: f32,
    yaw: f32,

    pub fn init(allocator: *std.mem.Allocator, movement_speed: f32, camera_sensitivity: f32) !Spectator {
        var camera = try allocator.create(rl.Camera3D);
        camera.position = rl.Vector3{ .x = 4, .y = 2, .z = 4 };
        camera.target = rl.Vector3{ .x = 0, .y = 1.8, .z = 0 };
        camera.up = rl.Vector3{ .x = 0, .y = 1, .z = 0 };
        camera.fovy = 60;
        camera.projection = .perspective;

        return Spectator{
            .allocator = allocator,
            .camera = camera,
            .camera_sensitivity = camera_sensitivity,
            .movement_speed = movement_speed,
            .pitch = 0.0,
            .yaw = 89.0,
        };
    }

    pub fn deinit(self: *Spectator) void {
        self.allocator.destroy(self.camera);
    }

    pub fn update(self: *Spectator, delta_time: f32) void {
        var position_change: rl.Vector3 = rl.Vector3{ .x = 0, .y = 0, .z = 0 };
        var yaw_radians = std.math.degreesToRadians(self.yaw);
        if (rl.isKeyDown(rl.KeyboardKey.w)) {
            position_change.z += @sin(yaw_radians);
            position_change.x += @cos(yaw_radians);
        } else if (rl.isKeyDown(rl.KeyboardKey.s)) {
            position_change.z += -@sin(yaw_radians);
            position_change.x += -@cos(yaw_radians);
        }
        if (rl.isKeyDown(rl.KeyboardKey.a)) {
            position_change.z += -@cos(yaw_radians);
            position_change.x += @sin(yaw_radians);
        } else if (rl.isKeyDown(rl.KeyboardKey.d)) {
            position_change.z += @cos(yaw_radians);
            position_change.x += -@sin(yaw_radians);
        }
        if (rl.isKeyDown(rl.KeyboardKey.space)) {
            position_change.y += 1.0;
        } else if (rl.isKeyDown(rl.KeyboardKey.left_shift)) {
            position_change.y += -1.0;
        }

        position_change = position_change.scale(delta_time * self.movement_speed);

        self.camera.position = self.camera.position.add(position_change);

        // Also update target vector

        // Get the mouse movement
        const mouse_delta = rl.getMouseDelta();

        self.pitch = std.math.clamp(self.pitch, -89.0, 89.0);

        self.yaw += mouse_delta.x * self.camera_sensitivity;
        self.pitch -= mouse_delta.y * self.camera_sensitivity;

        yaw_radians = std.math.degreesToRadians(self.yaw);
        const pitch_radians = std.math.degreesToRadians(self.pitch);

        // Convert angles to direction vector
        const direction = rl.Vector3{
            .x = @cos(yaw_radians) * @cos(pitch_radians),
            .y = @sin(pitch_radians),
            .z = @sin(yaw_radians) * @cos(pitch_radians),
        };

        self.camera.target = self.camera.position.add(direction);
    }
};

pub const Sim = struct {
    allocator: *std.mem.Allocator,

    window_height: i32,
    window_width: i32,

    spectator: *Spectator,

    cursor_enabled: bool,

    pub fn init(allocator: *std.mem.Allocator, window_height: i32, window_width: i32, movement_speed: f32, camera_sensitivity: f32) !Sim {
        rl.setConfigFlags(.{ .window_resizable = true });

        rl.initWindow(
            window_width,
            window_height,
            "Zigualizer",
        );

        rl.disableCursor();

        const spectator: *Spectator = try allocator.create(Spectator);
        spectator.* = try Spectator.init(allocator, movement_speed, camera_sensitivity);

        return Sim{
            .allocator = allocator,
            .window_height = window_height,
            .window_width = window_width,
            .cursor_enabled = false,
            .spectator = spectator,
        };
    }

    pub fn deinit(self: *Sim) void {
        self.spectator.deinit();
        self.allocator.destroy(self.spectator);
    }

    pub fn run(self: *Sim) !void {
        // Create some polygons
        var polygon_points = try self.allocator.alloc([]rl.Vector3, 3);
        defer {
            for (polygon_points) |points| {
                self.allocator.free(points);
            }
            self.allocator.free(polygon_points);
        }

        // Create a triangle
        polygon_points[0] = try self.allocator.alloc(rl.Vector3, 3);
        polygon_points[0][0] = rl.Vector3{ .x = 0, .y = 0, .z = 0 };
        polygon_points[0][1] = rl.Vector3{ .x = 1, .y = 0, .z = 0 };
        polygon_points[0][2] = rl.Vector3{ .x = 0, .y = 1, .z = 0 };

        // Create a square
        polygon_points[1] = try self.allocator.alloc(rl.Vector3, 4);
        polygon_points[1][0] = rl.Vector3{ .x = 0, .y = 0, .z = 1 };
        polygon_points[1][1] = rl.Vector3{ .x = 1, .y = 0, .z = 1 };
        polygon_points[1][2] = rl.Vector3{ .x = 1, .y = 1, .z = 1 };
        polygon_points[1][3] = rl.Vector3{ .x = 0, .y = 1, .z = 1 };

        // Create a pentagon
        polygon_points[2] = try self.allocator.alloc(rl.Vector3, 5);
        polygon_points[2][0] = rl.Vector3{ .x = 0, .y = 0, .z = 2 };
        polygon_points[2][1] = rl.Vector3{ .x = 1, .y = 0, .z = 2 };
        polygon_points[2][2] = rl.Vector3{ .x = 1.5, .y = 0.5, .z = 2 };
        polygon_points[2][3] = rl.Vector3{ .x = 0.5, .y = 1, .z = 2 };
        polygon_points[2][4] = rl.Vector3{ .x = -0.5, .y = 0.5, .z = 2 };

        const polygons = [_]render.Polygon{
            .{ .points = polygon_points[0], .color = rl.Color.red },
            .{ .points = polygon_points[1], .color = rl.Color.blue },
            .{ .points = polygon_points[2], .color = rl.Color.green },
        };

        defer rl.closeWindow();

        // I want the escape to escape the cursor being locked
        while (!(rl.windowShouldClose() and !rl.isKeyDown(rl.KeyboardKey.escape))) {
            if (rl.isKeyPressed(rl.KeyboardKey.escape)) {
                if (self.cursor_enabled) {
                    rl.disableCursor();
                    self.cursor_enabled = false;
                } else {
                    rl.enableCursor();
                    self.cursor_enabled = true;
                }
            }

            self.spectator.update(rl.getFrameTime());

            // Render
            rl.beginDrawing();
            defer rl.endDrawing();

            rl.clearBackground(rl.Color.ray_white);

            {
                self.spectator.camera.begin();
                defer self.spectator.camera.end();

                // Render axes
                rl.drawLine3D(rl.Vector3{ .x = -1, .y = 0, .z = 0 }, rl.Vector3{ .x = 1, .y = 0, .z = 0 }, rl.Color.black);
                rl.drawLine3D(rl.Vector3{ .x = 0, .y = -1, .z = 0 }, rl.Vector3{ .x = 0, .y = 1, .z = 0 }, rl.Color.black);
                rl.drawLine3D(rl.Vector3{ .x = 0, .y = 0, .z = -1 }, rl.Vector3{ .x = 0, .y = 0, .z = 1 }, rl.Color.black);

                // Render polygons
                for (polygons) |polygon| {
                    try polygon.render();
                }
            }

            rl.drawFPS(10, 10);
        }
    }
};
