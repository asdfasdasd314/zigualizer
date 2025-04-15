const rl = @import("raylib");
const std = @import("std");

pub const TextInput = @This();
    
bounds: rl.Rectangle,
text: std.ArrayList(u8),
is_active: bool,
cursor_pos: usize,
cursor_timer: f32,
show_cursor: bool,

pub fn init(allocator: *std.mem.Allocator, bounds: rl.Rectangle, initial_text: []const u8) !TextInput {
    var input = TextInput{
        .bounds = bounds,
        .text = std.ArrayList(u8).init(allocator.*),
        .is_active = false,
        .cursor_pos = 0,
        .cursor_timer = 0,
        .show_cursor = true,
    };
    try input.text.appendSlice(initial_text);
    input.cursor_pos = input.text.items.len;
    return input;
}

pub fn deinit(self: *TextInput) void {
    self.text.deinit();
}

pub fn update(self: *TextInput, mouse_pos: rl.Vector2) !void {
    // Update cursor blink
    self.cursor_timer += rl.getFrameTime();
    if (self.cursor_timer >= 0.5) {
        self.cursor_timer = 0;
        self.show_cursor = !self.show_cursor;
    }

    // Check for click
    if (rl.isMouseButtonPressed(rl.MouseButton.left)) {
        self.is_active = rl.checkCollisionPointRec(mouse_pos, self.bounds);
        if (self.is_active) {
            // Calculate cursor position based on click
            const click_x = mouse_pos.x - self.bounds.x;
            var new_pos: usize = 0;
            var text_width: f32 = 0;
            const char_width: f32 = 12; // Approximate character width
            while (new_pos < self.text.items.len) : (new_pos += 1) {
                if (text_width + char_width / 2 > click_x) break;
                text_width += char_width;
            }
            self.cursor_pos = new_pos;
        }
    }

    if (self.is_active) {
        // Handle text input
        const key = rl.getCharPressed();
        if (key != 0) {
            if (self.text.items.len < 32) { // Limit text length
                try self.text.insert(self.cursor_pos, @intCast(key));
                self.cursor_pos += 1;
            }
        }

        // Handle backspace
        if (rl.isKeyPressed(rl.KeyboardKey.backspace) and self.cursor_pos > 0) {
            _ = self.text.orderedRemove(self.cursor_pos - 1);
            self.cursor_pos -= 1;
        }

        // Handle delete
        if (rl.isKeyPressed(rl.KeyboardKey.delete) and self.cursor_pos < self.text.items.len) {
            _ = self.text.orderedRemove(self.cursor_pos);
        }

        // Handle left arrow
        if (rl.isKeyPressed(rl.KeyboardKey.left) and self.cursor_pos > 0) {
            self.cursor_pos -= 1;
        }

        // Handle right arrow
        if (rl.isKeyPressed(rl.KeyboardKey.right) and self.cursor_pos < self.text.items.len) {
            self.cursor_pos += 1;
        }
    }
}

pub fn draw(self: *TextInput, allocator: *std.mem.Allocator) !void {
    // Draw background
    rl.drawRectangleRec(self.bounds, if (self.is_active) rl.Color.white else rl.Color{ .r = 200, .g = 200, .b = 200, .a = 255 });
    rl.drawRectangleLinesEx(self.bounds, 1, if (self.is_active) rl.Color.blue else rl.Color.gray);

    // Draw text
    if (self.text.items.len > 0) {
        const text_x = self.bounds.x + 5; // Left align text
        const null_terminated = try std.fmt.allocPrintZ(allocator.*, "{s}", .{self.text.items});
        defer allocator.free(null_terminated);
        rl.drawText(null_terminated, @intFromFloat(text_x), @intFromFloat(self.bounds.y + 5), 20, rl.Color.black);
    }

    // Draw cursor
    if (self.is_active and self.show_cursor) {
        const cursor_x = self.bounds.x + 5 + @as(f32, @floatFromInt(self.cursor_pos)) * 12; // Left align cursor
        rl.drawLine(@intFromFloat(cursor_x), @intFromFloat(self.bounds.y + 5), @intFromFloat(cursor_x), @intFromFloat(self.bounds.y + self.bounds.height - 5), rl.Color.black);
    }
}