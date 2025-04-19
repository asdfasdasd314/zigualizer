const rl = @import("raylib");
const std = @import("std");

pub const TextInput = @This();

bounds: rl.Rectangle,
text: std.ArrayList(u8),
temp_text: std.ArrayList(u8),
is_active: bool,
cursor_pos: usize,
cursor_timer: f32,
show_cursor: bool,
max_length: usize,

pub fn init(allocator: *std.mem.Allocator, bounds: rl.Rectangle, initial_text: []const u8) !TextInput {
    var input = TextInput{
        .bounds = bounds,
        .text = std.ArrayList(u8).init(allocator.*),
        .temp_text = std.ArrayList(u8).init(allocator.*),
        .is_active = false,
        .cursor_pos = 0,
        .cursor_timer = 0,
        .max_length = 32,
        .show_cursor = true,
    };
    try input.text.appendSlice(initial_text);
    try input.temp_text.appendSlice(initial_text);
    input.cursor_pos = input.text.items.len;
    return input;
}

pub fn deinit(self: *TextInput) void {
    self.text.deinit();
    self.temp_text.deinit();
}

pub fn getValue(self: *TextInput) !f32 {
    return std.fmt.parseFloat(f32, self.text.items) catch 0.0;
}

pub fn update(self: *TextInput, mouse_pos: rl.Vector2, allocator: *std.mem.Allocator) !void {
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
            const click_x = mouse_pos.x - self.bounds.x - 7.5; // Account for padding
            var new_pos: usize = 0;
            var best_pos: usize = 0;
            var min_diff: f32 = std.math.floatMax(f32);

            // Try each possible cursor position to find the closest to click_x
            while (new_pos <= self.temp_text.items.len) : (new_pos += 1) {
                const text_up_to_pos = if (new_pos > 0) self.temp_text.items[0..new_pos] else "";
                const null_terminated = try std.fmt.allocPrintZ(allocator.*, "{s}", .{text_up_to_pos});
                defer allocator.free(null_terminated);
                const text_width = @as(f32, @floatFromInt(rl.measureText(null_terminated, 16)));
                const diff = @abs(text_width - click_x);
                if (diff < min_diff) {
                    min_diff = diff;
                    best_pos = new_pos;
                }
            }
            self.cursor_pos = best_pos;
        }
    }

    if (self.is_active) {
        // Handle text input
        const key = rl.getCharPressed();
        if (key != 0) {
            if (self.temp_text.items.len >= self.max_length) {
                return;
            }

            // Allow numbers, decimal point, and minus sign
            if ((key < '0' or key > '9') and key != '.' and key != '-') {
                return;
            }

            // Only allow one decimal point
            if (key == '.' and std.mem.indexOfScalar(u8, self.temp_text.items, '.') != null) {
                return;
            }

            // Only allow minus sign at the start
            if (key == '-' and self.cursor_pos != 0) {
                return;
            }

            try self.temp_text.insert(self.cursor_pos, @intCast(key));
            self.cursor_pos += 1;
        }

        // Handle backspace
        if (rl.isKeyPressed(rl.KeyboardKey.backspace) and self.cursor_pos > 0) {
            _ = self.temp_text.orderedRemove(self.cursor_pos - 1);
            self.cursor_pos -= 1;
        }

        // Handle delete
        if (rl.isKeyPressed(rl.KeyboardKey.delete) and self.cursor_pos < self.temp_text.items.len) {
            _ = self.temp_text.orderedRemove(self.cursor_pos);
        }

        // Handle left arrow
        if (rl.isKeyPressed(rl.KeyboardKey.left) and self.cursor_pos > 0) {
            self.cursor_pos -= 1;
        }

        // Handle right arrow
        if (rl.isKeyPressed(rl.KeyboardKey.right) and self.cursor_pos < self.temp_text.items.len) {
            self.cursor_pos += 1;
        }

        // Handle enter key
        if (rl.isKeyPressed(rl.KeyboardKey.enter)) {
            // Validate the input
            if (self.temp_text.items.len > 0) {
                if (std.fmt.parseFloat(f32, self.temp_text.items)) |_| {
                    // If parsing succeeds, update the actual text
                    self.text.clearRetainingCapacity();
                    try self.text.appendSlice(self.temp_text.items);
                    self.cursor_pos = self.text.items.len;
                } else |_| {
                    // If parsing fails, revert to the original text
                    self.temp_text.clearRetainingCapacity();
                    try self.temp_text.appendSlice(self.text.items);
                    self.cursor_pos = self.temp_text.items.len;
                }
            }

            self.is_active = false;
        }
    }
}

pub fn draw(self: *TextInput, allocator: *std.mem.Allocator) !void {
    // Draw background
    rl.drawRectangleRec(self.bounds, if (self.is_active) rl.Color.white else rl.Color{ .r = 200, .g = 200, .b = 200, .a = 255 });
    rl.drawRectangleLinesEx(self.bounds, 1, if (self.is_active) rl.Color.blue else rl.Color.gray);

    // Draw text
    if (self.temp_text.items.len > 0) {
        const text_x = self.bounds.x + 5; // Left align text
        const null_terminated = try std.fmt.allocPrintZ(allocator.*, "{s}", .{self.temp_text.items});
        defer allocator.free(null_terminated);
        rl.drawText(null_terminated, @intFromFloat(text_x), @intFromFloat(self.bounds.y + 3), 16, rl.Color.black);
    }

    // Draw cursor
    if (self.is_active and self.show_cursor) {
        // Get the text up to the cursor position
        const text_up_to_cursor = if (self.cursor_pos > 0) self.temp_text.items[0..self.cursor_pos] else "";
        const null_terminated = try std.fmt.allocPrintZ(allocator.*, "{s}", .{text_up_to_cursor});
        defer allocator.free(null_terminated);
        const text_width = rl.measureText(null_terminated, 16);
        const cursor_x = self.bounds.x + 7.5 + @as(f32, @floatFromInt(text_width));
        rl.drawLine(@intFromFloat(cursor_x), @intFromFloat(self.bounds.y + 2), @intFromFloat(cursor_x), @intFromFloat(self.bounds.y + self.bounds.height - 2), rl.Color.black);
    }
}
