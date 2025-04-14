// Renderable objects go here
const rl = @import("raylib");
const math = @import("math.zig");

const InvalidPolygonError = error{
    TwoPoints,
};

pub const Cube = struct {
    p0: rl.Vector3,
    width: f32,
    height: f32,
    length: f32,
    color: rl.Color,

    size: f32 = 1.0,

    pub fn render(self: *Cube) !void {
        rl.drawCube(self.p0.scale(self.size), self.width * self.size, self.height * self.size, self.length * self.size, self.color);
    }

    pub fn setSize(self: *Cube, scalar: f32) !void {
        self.size = scalar;
    }

    pub fn projectOntoPlane(self: *Cube, plane: math.Plane) !void {
        const p0 = self.p0.scale(self.size);
        const points = [_]rl.Vector3{
            p0,
            p0.add(rl.Vector3{ .x = self.width * self.size, .y = 0, .z = 0 }),
            p0.add(rl.Vector3{ .x = self.width * self.size, .y = 0, .z = self.length * self.size }),
            p0.add(rl.Vector3{ .x = 0, .y = 0, .z = self.length * self.size }),
            p0.add(rl.Vector3{ .x = 0, .y = self.height * self.size, .z = self.length * self.size }),
            p0.add(rl.Vector3{ .x = self.width * self.size, .y = self.height * self.size, .z = self.length * self.size }),
            p0.add(rl.Vector3{ .x = self.width * self.size, .y = self.height * self.size, .z = 0 }),
            p0.add(rl.Vector3{ .x = 0, .y = self.height * self.size, .z = 0 }),
        };

        for (points) |point| {
            const projected = plane.project(point);
            rl.drawCircle3D(projected, 1, rl.Color.black);
        }
    }
};

pub const Polygon = struct {
    points: []rl.Vector3,
    color: rl.Color,

    size: f32 = 1.0,

    pub fn setSize(self: *Polygon, scalar: f32) !void {
        self.size = scalar;
    }

    /// It is assumed that the points provided as an input to this function are sorted CLOCKWISE, otherwise this function will not work
    pub fn render(self: *Polygon) !void {
        if (self.points.len < 3) {
            return InvalidPolygonError.TwoPoints;
        }

        for (1..self.points.len - 1) |i| {
            rl.drawTriangle3D(self.points[0].scale(self.size), self.points[i].scale(self.size), self.points[i + 1].scale(self.size), self.color);
            // We have to add the below line as well so that the backside of the polygon is also rendered
            rl.drawTriangle3D(self.points[0].scale(self.size), self.points[i + 1].scale(self.size), self.points[i].scale(self.size), self.color);
        }
    }
};

pub const Axes = struct {
    precision: i32,
    arrow_height: f32,
    arrow_radius: f32,
    scalar: f32 = 1.0,
    default_size: f32,
    thickness: f32 = 0.1,

    pub fn setScale(self: *Axes, scalar: f32) !void {
        self.scalar = scalar;
    }

    pub fn setThickness(self: *Axes, thickness: f32) !void {
        self.thickness = thickness;
    }

    pub fn render(self: *Axes) !void {
        // X-axis (red)
        rl.drawCylinderEx(rl.Vector3{ .x = -self.default_size * self.scalar, .y = 0, .z = 0 }, rl.Vector3{ .x = self.default_size * self.scalar, .y = 0, .z = 0 }, self.thickness, self.thickness, self.precision, rl.Color.red);
        // X-axis arrows
        rl.drawCylinderEx(rl.Vector3{ .x = self.default_size * self.scalar, .y = 0, .z = 0 }, rl.Vector3{ .x = self.default_size * self.scalar + self.arrow_height, .y = 0, .z = 0 }, self.arrow_radius, 0, self.precision, rl.Color.red);
        rl.drawCylinderEx(rl.Vector3{ .x = -self.default_size * self.scalar, .y = 0, .z = 0 }, rl.Vector3{ .x = -self.default_size * self.scalar - self.arrow_height, .y = 0, .z = 0 }, self.arrow_radius, 0, self.precision, rl.Color.red);

        // Y-axis (green)
        rl.drawCylinderEx(rl.Vector3{ .x = 0, .y = -self.default_size * self.scalar, .z = 0 }, rl.Vector3{ .x = 0, .y = self.default_size * self.scalar, .z = 0 }, self.thickness, self.thickness, self.precision, rl.Color.green);
        // Y-axis arrows
        rl.drawCylinderEx(rl.Vector3{ .x = 0, .y = self.default_size * self.scalar, .z = 0 }, rl.Vector3{ .x = 0, .y = self.default_size * self.scalar + self.arrow_height, .z = 0 }, self.arrow_radius, 0, self.precision, rl.Color.green);
        rl.drawCylinderEx(rl.Vector3{ .x = 0, .y = -self.default_size * self.scalar, .z = 0 }, rl.Vector3{ .x = 0, .y = -self.default_size * self.scalar - self.arrow_height, .z = 0 }, self.arrow_radius, 0, self.precision, rl.Color.green);

        // Z-axis (blue)
        rl.drawCylinderEx(rl.Vector3{ .x = 0, .y = 0, .z = -self.default_size * self.scalar }, rl.Vector3{ .x = 0, .y = 0, .z = self.default_size * self.scalar }, self.thickness, self.thickness, self.precision, rl.Color.blue);
        // Z-axis arrows
        rl.drawCylinderEx(rl.Vector3{ .x = 0, .y = 0, .z = self.default_size * self.scalar }, rl.Vector3{ .x = 0, .y = 0, .z = self.default_size * self.scalar + self.arrow_height }, self.arrow_radius, 0, self.precision, rl.Color.blue);
        rl.drawCylinderEx(rl.Vector3{ .x = 0, .y = 0, .z = -self.default_size * self.scalar }, rl.Vector3{ .x = 0, .y = 0, .z = -self.default_size * self.scalar - self.arrow_height }, self.arrow_radius, 0, self.precision, rl.Color.blue);
    }
};
