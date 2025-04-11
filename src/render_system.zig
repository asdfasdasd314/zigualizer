const rl = @import("raylib");
const std = @import("std");
const geometry = @import("geometry.zig");

pub const RenderableTag = enum {
    polygon,
    cube,
};

pub const Renderable = union(RenderableTag) {
    polygon: *const geometry.Polygon,
    cube: *const geometry.Cube,
};

/// A system that manages and renders multiple renderable objects
pub const RenderSystem = struct {
    allocator: *std.mem.Allocator,
    renderables: std.ArrayList(Renderable),

    pub fn init(allocator: *std.mem.Allocator) !RenderSystem {
        return .{
            .allocator = allocator,
            .renderables = std.ArrayList(Renderable).init(allocator.*),
        };
    }

    pub fn deinit(self: *RenderSystem) void {
        self.renderables.deinit();
    }

    /// Adds a renderable object to the system
    pub fn addRenderable(self: *RenderSystem, renderable: Renderable) !void {
        try self.renderables.append(renderable);
    }

    /// Renders all objects in the system
    pub fn renderAll(self: *const RenderSystem) !void {
        for (self.renderables.items) |renderable| {
            switch (renderable) {
                .polygon => |polygon| try polygon.render(),
                .cube => |cube| try cube.render(),
            }
        }
    }
};
