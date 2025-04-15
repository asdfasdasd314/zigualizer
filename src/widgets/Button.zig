const rl = @import("raylib");
const std = @import("std");

pub const Button = @This();

allocator: *std.mem.Allocator,
bounds: rl.Rectangle,
text: [:0]const u8,
is_active: bool,

pub fn init(allocator: *std.mem.Allocator, bounds: rl.Rectangle, text: []const u8) !Button {
    const null_terminated_text = try std.fmt.allocPrintZ(allocator.*, "{s}", .{text});
    return Button{
        .allocator = allocator,
        .bounds = bounds,
        .text = null_terminated_text,
        .is_active = false,
    };
}

pub fn deinit(self: *Button) void {
    self.allocator.free(self.text);
}

pub fn update(self: *Button, mouse_pos: rl.Vector2) !void {
    self.is_active = rl.checkCollisionPointRec(mouse_pos, self.bounds);
}

pub fn draw(self: *Button) !void {
    if (self.is_active) {
        rl.drawRectangleRec(self.bounds, rl.Color.gray);
    } else {
        rl.drawRectangleRec(self.bounds, rl.Color.light_gray);
    }
    rl.drawText(self.text, @intFromFloat(self.bounds.x + 10), @intFromFloat(self.bounds.y + 10), 20, rl.Color.black);
}
