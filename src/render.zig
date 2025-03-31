// Renderable objects go here
const rl = @import("raylib");

const InvalidPolygonError = error{
    TwoPoints,
};

pub const Polygon = struct {
    points: []rl.Vector3,
    color: rl.Color,

    /// It is assumed that the points provided as an input to this function are sorted CLOCKWISE, otherwise this function will not work
    pub fn render(self: *const Polygon) !void {
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