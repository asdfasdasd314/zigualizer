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

    pub fn render(self: *Cube) !void {
        rl.drawCube(self.p0, self.width, self.height, self.length, self.color);
    }

    pub fn scale(self: *Cube, scalar: f32) !void {
        self.p0 = self.p0.scale(scalar);
        self.width *= scalar;
        self.height *= scalar;
        self.length *= scalar;
    }

    pub fn projectOntoPlane(self: *Cube, plane: math.Plane) !void {
        const points = [_]rl.Vector3{
            self.p0,
            self.p0.add(rl.Vector3{ .x = self.width, .y = 0, .z = 0 }),
            self.p0.add(rl.Vector3{ .x = self.width, .y = 0, .z = self.length }),
            self.p0.add(rl.Vector3{ .x = 0, .y = 0, .z = self.length }),
            self.p0.add(rl.Vector3{ .x = 0, .y = self.height, .z = self.length }),
            self.p0.add(rl.Vector3{ .x = self.width, .y = self.height, .z = self.length }),
            self.p0.add(rl.Vector3{ .x = self.width, .y = self.height, .z = 0 }),
            self.p0.add(rl.Vector3{ .x = 0, .y = self.height, .z = 0 }),
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

    pub fn scale(self: *Polygon, scalar: f32) !void {
        for (0..self.points.len) |i| {
            self.points[i] = self.points[i].scale(scalar);
        }
    }

    /// It is assumed that the points provided as an input to this function are sorted CLOCKWISE, otherwise this function will not work
    pub fn render(self: *Polygon) !void {
        if (self.points.len < 3) {
            return InvalidPolygonError.TwoPoints;
        }

        for (1..self.points.len - 1) |i| {
            rl.drawTriangle3D(self.points[0], self.points[i], self.points[i + 1], self.color);
            // We have to add the below line as well so that the backside of the polygon is also rendered
            rl.drawTriangle3D(self.points[0], self.points[i + 1], self.points[i], self.color);
        }
    }
};

pub const Axes = struct {
    size: f32,

    pub fn scale(self: *Axes, scalar: f32) !void {
        self.size *= scalar;
    }

    pub fn render(self: *Axes) !void {
        rl.drawLine3D(rl.Vector3{ .x = -self.size, .y = 0, .z = 0 }, rl.Vector3{ .x = self.size, .y = 0, .z = 0 }, rl.Color.red);
        rl.drawLine3D(rl.Vector3{ .x = 0, .y = -self.size, .z = 0 }, rl.Vector3{ .x = 0, .y = self.size, .z = 0 }, rl.Color.green);
        rl.drawLine3D(rl.Vector3{ .x = 0, .y = 0, .z = -self.size }, rl.Vector3{ .x = 0, .y = 0, .z = self.size }, rl.Color.blue);
    }
};
