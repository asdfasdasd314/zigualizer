const rl = @import("raylib");
const std = @import("std");
const render_system = @import("render_system.zig");
const geometry = @import("geometry.zig");
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
    axes: *geometry.Axes,
    render_system: *render_system.RenderSystem,

    in_menu: bool,

    base_movement_speed: f32,

    pub fn init(
        allocator: *std.mem.Allocator,
        window_height: i32,
        window_width: i32,
        movement_speed: f32,
        camera_sensitivity: f32,
        renderables: []render_system.Renderable,
    ) !Sim {
        rl.setConfigFlags(.{ .window_resizable = true });

        rl.initWindow(
            window_width,
            window_height,
            "Zigualizer",
        );

        rl.disableCursor();

        const spectator: *Spectator = try allocator.create(Spectator);
        spectator.* = try Spectator.init(allocator, movement_speed, camera_sensitivity);

        const render_system_ptr: *render_system.RenderSystem = try allocator.create(render_system.RenderSystem);
        render_system_ptr.* = try render_system.RenderSystem.init(allocator);

        // Add all renderables to the render system
        for (renderables) |renderable| {
            try render_system_ptr.addRenderable(renderable);
        }

        const axes: *geometry.Axes = try allocator.create(geometry.Axes);
        axes.* = geometry.Axes{ .size = 10 };

        return Sim{
            .allocator = allocator,
            .window_height = window_height,
            .window_width = window_width,
            .in_menu = false,
            .spectator = spectator,
            .render_system = render_system_ptr,
            .base_movement_speed = movement_speed,
            .axes = axes,
        };
    }

    pub fn deinit(self: *Sim) void {
        self.spectator.deinit();
        self.render_system.deinit();
        self.allocator.destroy(self.spectator);
        self.allocator.destroy(self.render_system);
        self.allocator.destroy(self.axes);
    }

    pub fn toggle_menu(self: *Sim) void {
        self.in_menu = !self.in_menu;
    }

    pub fn run(self: *Sim) !void {
        defer rl.closeWindow();

        // I want the escape to escape the cursor being locked
        while (!(rl.windowShouldClose() and !rl.isKeyDown(rl.KeyboardKey.escape))) {
            if (rl.isKeyPressed(rl.KeyboardKey.escape)) {
                if (self.in_menu) {
                    rl.disableCursor();
                    self.in_menu = false;
                } else {
                    rl.enableCursor();
                    self.in_menu = true;
                }
            }

            // Handle mouse wheel input
            const wheel_move = rl.getMouseWheelMove();
            if (wheel_move != 0) {
                if (self.in_menu) {
                    try self.render_system.scaleAll(@exp(wheel_move * 0.1));
                } else {
                    self.spectator.movement_speed = self.base_movement_speed * @exp(wheel_move * 0.2);
                }
            }

            // Begin drawing
            rl.beginDrawing();
            defer rl.endDrawing();

            rl.clearBackground(rl.Color.ray_white);

            if (!self.in_menu) {
                self.spectator.update(rl.getFrameTime());
                rl.drawFPS(10, 10);
            }

            // Always render the 3D scene
            {
                self.spectator.camera.begin();
                defer self.spectator.camera.end();

                // Draw scaled axes
                try self.axes.render();

                try self.render_system.renderAll();
            }

            // Draw menu on top if in menu
            if (self.in_menu) {
                rl.drawText("Zigualizer", 10, 10, 20, rl.Color.black);
                rl.drawText("Press ESC to toggle menu", 10, 30, 20, rl.Color.black);
                rl.drawText("Scroll to adjust axes scale", 10, 50, 20, rl.Color.black);
            } else {
                rl.drawText("Scroll to adjust movement speed", 10, 50, 20, rl.Color.black);
            }
        }
    }
};
