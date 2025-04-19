const rl = @import("raylib");
const std = @import("std");
const Sim = @import("../sim.zig").Sim;
pub const Button = @This();

allocator: *std.mem.Allocator,
bounds: rl.Rectangle,
text: [:0]const u8,
clicked: bool,
is_active: bool,
sim: *Sim,
on_click: ?*const fn (*Button, *Sim) void,

pub fn init(allocator: *std.mem.Allocator, bounds: rl.Rectangle, text: []const u8, on_click: ?*const fn (*Button, *Sim) void, sim: *Sim) !Button {
    const null_terminated_text = try std.fmt.allocPrintZ(allocator.*, "{s}", .{text});
    return Button{
        .allocator = allocator,
        .bounds = bounds,
        .text = null_terminated_text,
        .is_active = false,
        .clicked = false,
        .on_click = on_click,
        .sim = sim,
    };
}

pub fn deinit(self: *Button) void {
    self.allocator.free(self.text);
}

pub fn update(self: *Button, mouse_pos: rl.Vector2) !void {
    const was_active = self.is_active;
    self.is_active = rl.checkCollisionPointRec(mouse_pos, self.bounds);

    // Call the click callback if the button was just clicked
    if (self.on_click) |callback| {
        if (was_active and !self.is_active and rl.isMouseButtonReleased(rl.MouseButton.left)) {
            callback(self, self.sim);
        }
    }
}

pub fn draw(self: *Button) !void {
    if (self.is_active) {
        rl.drawRectangleRec(self.bounds, rl.Color.gray);
    } else {
        rl.drawRectangleRec(self.bounds, rl.Color.light_gray);
    }
    rl.drawText(self.text, @intFromFloat(self.bounds.x + 10), @intFromFloat(self.bounds.y + 10), 20, rl.Color.black);
}
