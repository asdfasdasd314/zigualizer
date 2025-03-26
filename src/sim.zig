const rl = @import("raylib");
const std = @import("std");

const MAX_COLUMNS = 20;

pub const Spectator = struct {
    allocator: *std.mem.Allocator,
    camera: *rl.Camera3D,

    camera_sensitivity: f32,
    movement_speed: f32,

    pitch: f32,
    yaw: f32,

    pub fn init(allocator: *std.mem.Allocator, movement_speed: f32, camera_sensitivity: f32) !Spectator {
        var camera = try allocator.create(rl.Camera3D);
        camera.position = .init(4, 2, 4);
        camera.target = .init(0, 1.8, 0);
        camera.up = .init(0, 1, 0);
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
        var position_change: rl.Vector3 = rl.Vector3{ .x = 0.0, .y = 0.0, .z = 0.0 };
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
    }

    pub fn run(self: *Sim) !void {
        defer rl.closeWindow();

        var heights: [MAX_COLUMNS]f32 = undefined;
        var positions: [MAX_COLUMNS]rl.Vector3 = undefined;
        var colors: [MAX_COLUMNS]rl.Color = undefined;

        for (0..heights.len) |i| {
            heights[i] = @as(f32, @floatFromInt(rl.getRandomValue(1, 12)));
            positions[i] = .init(
                @as(f32, @floatFromInt(rl.getRandomValue(-15, 15))),
                heights[i] / 2.0,
                @as(f32, @floatFromInt(rl.getRandomValue(-15, 15))),
            );
            colors[i] = .init(
                @as(u8, @intCast(rl.getRandomValue(20, 255))),
                @as(u8, @intCast(rl.getRandomValue(10, 55))),
                30,
                255,
            );
        }

        // I want the escape to escape the cursor being locked
        while (!(rl.windowShouldClose() and !rl.isKeyDown(rl.KeyboardKey.escape))) {
            if (rl.isKeyPressed(rl.KeyboardKey.escape)) {
                if (self.cursor_enabled) {
                    rl.disableCursor();
                    self.cursor_enabled = false;
                }
                else {
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

                // Draw ground
                rl.drawPlane(.init(0, 0, 0), .init(32, 32), .light_gray);
                rl.drawCube(.init(-16.0, 2.5, 0.0), 1.0, 5.0, 32.0, .blue); // Draw a blue wall
                rl.drawCube(.init(16.0, 2.5, 0.0), 1.0, 5.0, 32.0, .lime); // Draw a green wall
                rl.drawCube(.init(0.0, 2.5, 16.0), 32.0, 5.0, 1.0, .gold); // Draw a yellow wall

                // Draw some cubes around
                for (heights, 0..) |height, i| {
                    rl.drawCube(positions[i], 2.0, height, 2.0, colors[i]);
                    rl.drawCubeWires(positions[i], 2.0, height, 2.0, .maroon);
                }
            }

            rl.drawRectangle(10, 10, 220, 70, .fade(.sky_blue, 0.5));
            rl.drawRectangleLines(10, 10, 220, 70, .blue);

            rl.drawText("First person camera default controls:", 20, 20, 10, .black);
            rl.drawText("- Move with keys: W, A, S, D", 40, 40, 10, .dark_gray);
            rl.drawText("- Mouse move to look around", 40, 60, 10, .dark_gray);
        }
    }
};
