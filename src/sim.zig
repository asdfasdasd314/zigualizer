const rl = @import("raylib");

pub const Sim = struct {
    window_height: i32,
    window_width: i32,
    window_title: [:0]const u8,

    pub fn setup(self: *const Sim) !void {
        rl.initWindow(
            self.window_width,
            self.window_height,
            self.window_title,
        );
    }

    pub fn run(_: *const Sim) !void {
        while (!rl.windowShouldClose()) {
            rl.beginDrawing();
            defer rl.endDrawing();

            rl.clearBackground(rl.Color.white);
            
            rl.drawCircle(@divFloor(rl.getScreenWidth(), 2), @divFloor(rl.getScreenHeight(), 2), 50.0, rl.Color.red);
        }
    }
};
