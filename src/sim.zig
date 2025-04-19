const rl = @import("raylib");
const gui = @import("raygui");
const std = @import("std");
const render_system = @import("render_system.zig");
const TextInput = @import("widgets/TextInput.zig");
const Button = @import("widgets/Button.zig");
const Spectator = @import("Spectator.zig");
const UIElement = @import("widgets/UIElement.zig");
const geometry = @import("geometry.zig");

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

    ui_elements: []UIElement,

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
            .ui_elements = undefined,
            .scale_lower_bound = 0.1,
            .scale_upper_bound = 100.0,
            .axes_scale_lower_bound = 0.1,
            .axes_scale_upper_bound = 100.0,
        };

        // Define callback functions
        const update_object_scale = struct {
            fn callback(input: *TextInput, sim_ptr: *Sim) void {
                if (input.getValue()) |value| {
                    if (value >= sim_ptr.scale_lower_bound and value <= sim_ptr.scale_upper_bound) {
                        sim_ptr.scale = value;
                        sim_ptr.render_system.setScale(sim_ptr.scale) catch {};
                    }
                } else |_| {}
            }
        }.callback;

        const update_axes_scale = struct {
            fn callback(input: *TextInput, sim_ptr: *Sim) void {
                if (input.getValue()) |value| {
                    if (value >= sim_ptr.axes_scale_lower_bound and value <= sim_ptr.axes_scale_upper_bound) {
                        sim_ptr.axes_scale = value;
                        sim_ptr.axes.setScale(sim_ptr.axes_scale) catch {};
                    }
                } else |_| {}
            }
        }.callback;

        const reset_object_scale = struct {
            fn callback(_: *Button, sim_ptr: *Sim) void {
                sim_ptr.scale = 1.0;
                sim_ptr.axes_scale = 1.0;
                sim_ptr.render_system.setScale(sim_ptr.scale) catch {};
                sim_ptr.axes.setScale(sim_ptr.axes_scale) catch {};
            }
        }.callback;

        // Initialize text input widgets
        const text_input1 = try TextInput.init(
            allocator,
            rl.Rectangle{ .x = 20, .y = 100, .width = 100, .height = 20 },
            try std.fmt.allocPrint(allocator.*, "{d:.2}", .{sim.scale}),
            &update_object_scale,
            &sim,
        );

        const text_input2 = try TextInput.init(
            allocator,
            rl.Rectangle{ .x = 20, .y = 160, .width = 100, .height = 20 },
            try std.fmt.allocPrint(allocator.*, "{d:.2}", .{sim.axes_scale}),
            &update_axes_scale,
            &sim,
        );

        // Initialize button widgets
        const button1 = try Button.init(
            allocator,
            rl.Rectangle{ .x = 20, .y = 220, .width = 100, .height = 20 },
            "Reset",
            &reset_object_scale,
            &sim,
        );

        const ui_element1 = try UIElement.init(text_input1);
        const ui_element2 = try UIElement.init(text_input2);
        const ui_element3 = try UIElement.init(button1);

        sim.ui_elements = [_]UIElement{ ui_element1, ui_element2, ui_element3 };

        return sim;
    }

    pub fn deinit(self: *Sim) void {
        self.spectator.deinit();
        self.render_system.deinit();
        self.allocator.destroy(self.spectator);
        self.allocator.destroy(self.render_system);
        self.allocator.destroy(self.axes);
        for (self.ui_elements) |ui_element| {
            ui_element.deinit();
        }
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

                // Update and draw ui elements
                for (self.ui_elements) |ui_element| {
                    try ui_element.update(mouse_pos, self.allocator);
                }

                for (self.ui_elements) |ui_element| {
                    try ui_element.draw(self.allocator);
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
