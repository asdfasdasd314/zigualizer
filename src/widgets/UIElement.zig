const std = @import("std");
const rl = @import("raylib");
const TextInput = @import("TextInput.zig");
const Button = @import("Button.zig");
const Sim = @import("../sim.zig").Sim;

const UIElementsTag = enum {
    text_input,
    button,
};

const UIElements = union(UIElementsTag) {
    text_input: *TextInput,
    button: *Button,
};

const UIElement = @This();

element: UIElements,

pub fn init(element: UIElements) !UIElement {
    return UIElement{
        .element = element,
    };
}

pub fn deinit(self: *UIElement) void {
    switch (self.element) {
        .text_input => |text_input| text_input.deinit(),
        .button => |button| button.deinit(),
    }
}

pub fn update(self: *UIElement, mouse_pos: rl.Vector2, allocator: *std.mem.Allocator) !void {
    switch (self.element) {
        .text_input => |text_input| text_input.update(mouse_pos, allocator),
        .button => |button| button.update(mouse_pos),
    }
}

pub fn draw(self: *UIElement, allocator: *std.mem.Allocator) !void {
    switch (self.element) {
        .text_input => |text_input| text_input.draw(allocator),
        .button => |button| button.draw(),
    }
}