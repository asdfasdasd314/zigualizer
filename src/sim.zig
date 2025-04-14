const rl = @import("raylib");
const gui = @import("raygui");
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
};

// Custom text input widget
const TextInput = struct {
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
};

pub const Sim = struct {
    allocator: *std.mem.Allocator,

    window_height: i32,
    window_width: i32,

    spectator: *Spectator,
    axes: *geometry.Axes,
    render_system: *render_system.RenderSystem,

    in_menu: bool,
    scale: f32,
    axes_scale: f32,
    axes_thickness: f32,
    active_textbox: ?usize, // Track which textbox is active (0 for object scale, 1 for axes scale)
    text_inputs: [2]TextInput, // Store text input widgets

    scale_lower_bound: f32,
    scale_upper_bound: f32,
    axes_scale_lower_bound: f32,
    axes_scale_upper_bound: f32,

    pub fn init(
        allocator: *std.mem.Allocator,
        window_height: i32,
        window_width: i32,
        camera_sensitivity: f32,
        movement_speed: f32,
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
        axes.* = geometry.Axes{ .precision = 20, .arrow_height = 0.5, .arrow_radius = 0.2, .default_size = 20.0 };

        var sim = Sim{
            .allocator = allocator,
            .window_height = window_height,
            .window_width = window_width,
            .in_menu = false,
            .spectator = spectator,
            .render_system = render_system_ptr,
            .axes = axes,
            .scale = 1.0,
            .axes_scale = 1.0,
            .axes_thickness = 0.1,
            .active_textbox = null,
            .text_inputs = undefined,
            .scale_lower_bound = 0.1,
            .scale_upper_bound = 100.0,
            .axes_scale_lower_bound = 0.1,
            .axes_scale_upper_bound = 100.0,
        };

        // Initialize text input widgets
        sim.text_inputs[0] = try TextInput.init(allocator, rl.Rectangle{ .x = 20, .y = 100, .width = 100, .height = 20 }, try std.fmt.allocPrint(allocator.*, "{d:.2}", .{sim.scale}));
        sim.text_inputs[1] = try TextInput.init(allocator, rl.Rectangle{ .x = 20, .y = 160, .width = 100, .height = 20 }, try std.fmt.allocPrint(allocator.*, "{d:.2}", .{sim.axes_scale}));

        return sim;
    }

    pub fn deinit(self: *Sim) void {
        self.spectator.deinit();
        self.render_system.deinit();
        self.allocator.destroy(self.spectator);
        self.allocator.destroy(self.render_system);
        self.allocator.destroy(self.axes);
        self.text_inputs[0].deinit();
        self.text_inputs[1].deinit();
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
                    self.active_textbox = null; // Deactivate textbox when closing menu
                } else {
                    rl.enableCursor();
                    self.in_menu = true;
                }
            }

            // Handle mouse wheel input
            const wheel_move = rl.getMouseWheelMove();
            if (wheel_move != 0 and !self.in_menu) {
                self.spectator.movement_speed = self.spectator.movement_speed * @exp(wheel_move * 0.001);
            }

            // Begin drawing
            rl.beginDrawing();
            defer rl.endDrawing();

            rl.clearBackground(rl.Color.ray_white);

            if (!self.in_menu) {
                self.spectator.update(rl.getFrameTime());
                rl.drawFPS(10, 10);
            }

            // Draw spectator position
            const pos = self.spectator.camera.position;
            const pos_text = try std.fmt.allocPrintZ(self.allocator.*, "Position: ({d:.2}, {d:.2}, {d:.2})", .{ pos.x, pos.y, pos.z });
            defer self.allocator.free(pos_text);
            const text_width = @as(i32, @intCast(pos_text.len * 12)); // Convert to i32
            const text_x = self.window_width - text_width - 10;
            rl.drawText(pos_text, text_x, 10, 20, rl.Color.black);

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
                // Draw menu background
                rl.drawRectangle(10, 10, 300, 300, rl.Color{ .r = 0, .g = 0, .b = 0, .a = 128 });

                // Draw title and instructions
                rl.drawText("Zigualizer", 20, 20, 20, rl.Color.white);
                rl.drawText("Press ESC to toggle menu", 20, 40, 20, rl.Color.white);

                const mouse_pos = rl.getMousePosition();

                // Update and draw text inputs
                try self.text_inputs[0].update(mouse_pos);
                try self.text_inputs[1].update(mouse_pos);

                // Draw object scale input
                rl.drawText("Object Scale", 20, 70, 20, rl.Color.white);
                try self.text_inputs[0].draw(self.allocator);

                // Draw axes scale input
                rl.drawText("Axes Scale", 20, 130, 20, rl.Color.white);
                try self.text_inputs[1].draw(self.allocator);

                // Handle enter key
                if (rl.isKeyPressed(rl.KeyboardKey.enter)) {
                    if (self.text_inputs[0].is_active) {
                        const parsed = try std.fmt.parseFloat(f32, self.text_inputs[0].text.items);
                        if (parsed != 0.0) {
                            if (parsed >= self.scale_lower_bound and parsed <= self.scale_upper_bound) {
                                self.scale = parsed;
                                try self.render_system.setScale(self.scale);
                                // Update text to match new scale
                                self.text_inputs[0].text.clearRetainingCapacity();
                                try self.text_inputs[0].text.appendSlice(try std.fmt.allocPrint(self.allocator.*, "{d:.2}", .{self.scale}));
                                self.text_inputs[0].cursor_pos = self.text_inputs[0].text.items.len;
                            }
                        }
                    } else if (self.text_inputs[1].is_active) {
                        const parsed = try std.fmt.parseFloat(f32, self.text_inputs[1].text.items);
                        if (parsed != 0.0) {
                            if (parsed >= self.axes_scale_lower_bound and parsed <= self.axes_scale_upper_bound) {
                                self.axes_scale = parsed;
                                try self.axes.setScale(self.axes_scale);
                                // Update text to match new scale
                                self.text_inputs[1].text.clearRetainingCapacity();
                                try self.text_inputs[1].text.appendSlice(try std.fmt.allocPrint(self.allocator.*, "{d:.2}", .{self.axes_scale}));
                                self.text_inputs[1].cursor_pos = self.text_inputs[1].text.items.len;
                            }
                        }
                    }
                }

                // Draw axes thickness slider
                rl.drawText("Axes Thickness", 20, 190, 20, rl.Color.white);
                const thickness_bounds = rl.Rectangle{ .x = 20, .y = 220, .width = 260, .height = 20 };
                const new_thickness = gui.guiSlider(thickness_bounds, "Thickness", "", &self.axes_thickness, 0.01, 1.0);
                if (new_thickness != 1.0) {
                    try self.axes.setThickness(self.axes_thickness);
                }
            } else {
                rl.drawText("Scroll to adjust movement speed", 10, 50, 20, rl.Color.black);
            }
        }
    }
};
