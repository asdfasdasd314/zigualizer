const std = @import("std");
const rl = @import("raylib");

const Spectator = @This();

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

    // Normalize horizontal movement if moving diagonally
    if (position_change.x != 0 and position_change.z != 0) {
        const length = @sqrt(position_change.x * position_change.x + position_change.z * position_change.z);
        position_change.x /= length;
        position_change.z /= length;
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