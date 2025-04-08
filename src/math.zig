const rl = @import("raylib");
const std = @import("std");

/// Error types that can occur during matrix construction
pub const MatrixConstructionError = error{
    /// The matrix has zero rows or columns
    InvalidSize,

    /// The matrix has inconsistent row lengths
    InvalidShape,
};

/// A generic matrix type with compile-time known dimensions
/// This type provides various matrix operations including multiplication, determinant calculation,
/// and matrix inversion.
pub fn Matrix(comptime rows: usize, comptime cols: usize) type {
    return struct {
        allocator: *const std.mem.Allocator,

        comptime rows: usize = rows,
        comptime cols: usize = cols,
        contents: [rows][cols]f32,

        /// Initializes a new matrix with the given contents
        ///
        /// `allocator`: The memory allocator to use
        ///
        /// `contents`: The initial matrix values
        ///
        /// Returns: A new matrix or an error if the dimensions are invalid
        pub fn init(allocator: *const std.mem.Allocator, contents: [rows][cols]f32) MatrixConstructionError!Matrix(rows, cols) {
            if (contents.len == 0) {
                return MatrixConstructionError.InvalidSize;
            }

            for (contents) |row| {
                if (row.len != cols) {
                    return MatrixConstructionError.InvalidShape;
                }
            }

            return Matrix(rows, cols){
                .allocator = allocator,
                .rows = rows,
                .cols = cols,
                .contents = contents,
            };
        }

        /// Updates the matrix contents with new values
        ///
        /// `contents`: The new matrix values
        pub fn setContents(self: *Matrix(rows, cols), contents: [rows][cols]f32) void {
            self.contents = contents;
        }

        /// Checks if two matrices are equal by comparing their contents
        ///
        /// `other`: The matrix to compare against
        ///
        /// Returns: `true` if the matrices are equal, `false` otherwise
        pub fn equals(self: *const Matrix(rows, cols), other: *const Matrix(rows, cols)) bool {
            for (0..rows) |i| {
                for (0..cols) |j| {
                    if (self.contents[i][j] != other.contents[i][j]) {
                        return false;
                    }
                }
            }
            return true;
        }

        /// Transforms a vector using this matrix
        /// The result is a new vector allocated using the matrix's allocator
        ///
        /// `vector`: The vector to transform
        ///
        /// Returns: A new transformed vector or an error if dimensions don't match
        ///
        /// Note: The caller is responsible for freeing the returned vector
        pub fn transformVector(self: *Matrix(rows, cols), vector: [cols]f32) ![]f32 {
            if (vector.len != self.cols) {
                return error.InvalidSize;
            }

            var result = try self.allocator.alloc(f32, self.rows);
            errdefer self.allocator.free(result);

            for (0..self.rows) |i| {
                result[i] = 0;
                for (0..self.cols) |j| {
                    result[i] += self.contents[i][j] * vector[j];
                }
            }

            return result;
        }

        /// Multiplies this matrix with another matrix
        /// The result is a new matrix of dimensions [`rows` x `other_cols`]
        ///
        /// `other_rows`: The number of rows in the other matrix
        ///
        /// `other_cols`: The number of columns in the other matrix
        ///
        /// `other`: The matrix to multiply with
        ///
        /// Returns: A new matrix or an error if dimensions are incompatible
        ///
        /// Note: The caller is responsible for freeing the returned matrix
        pub fn matrixMultiply(
            self: *Matrix(rows, cols),
            comptime other_rows: usize,
            comptime other_cols: usize,
            other: *const Matrix(other_rows, other_cols),
        ) !Matrix(rows, other_cols) {
            if (self.cols != other.rows) {
                return error.MismatchedShapes;
            }

            // Initialize contents array
            var contents: [rows][other_cols]f32 = undefined;
            for (0..self.rows) |i| {
                for (0..other_cols) |j| {
                    var sum: f32 = 0;
                    for (0..self.cols) |k| {
                        sum += self.contents[i][k] * other.contents[k][j];
                    }
                    contents[i][j] = sum;
                }
            }

            return Matrix(rows, other_cols).init(other.allocator, contents);
        }

        /// Checks if the matrix is square (has equal number of rows and columns)
        ///
        /// Returns: `true` if the matrix is square, `false` otherwise
        pub fn isSquare(self: *Matrix(rows, cols)) bool {
            return self.rows == self.cols;
        }

        /// Calculates the determinant of the matrix using Gaussian elimination
        ///
        /// Returns: The determinant value or `null` if the matrix is not square
        ///
        /// Note: This operation has O(n^3) time complexity and may lose precision for large matrices
        pub fn determinant(self: *Matrix(rows, cols)) !?f32 {
            if (!self.isSquare()) {
                return null;
            }

            var temp = try Matrix(rows, cols).init(self.allocator, self.contents);
            var sign: f32 = 1;

            for (0..temp.rows - 1) |i| {
                // Find the pivot
                var max_row = i;
                var max_val = @abs(temp.contents[i][i]);
                for (i + 1..temp.rows) |j| {
                    const abs_val = @abs(temp.contents[j][i]);
                    if (abs_val > max_val) {
                        max_val = abs_val;
                        max_row = j;
                    }
                }

                // If the pivot is too small, the matrix is singular
                if (@abs(temp.contents[max_row][i]) < 1e-10) {
                    return 0;
                }

                // Swap rows if necessary
                if (max_row != i) {
                    const tmp = temp.contents[i];
                    temp.contents[i] = temp.contents[max_row];
                    temp.contents[max_row] = tmp;
                    sign *= -1;
                }

                // Eliminate column i
                for (i + 1..temp.rows) |j| {
                    const factor = temp.contents[j][i] / temp.contents[i][i];
                    for (i..temp.cols) |k| {
                        temp.contents[j][k] -= factor * temp.contents[i][k];
                    }
                }
            }

            // Compute determinant as product of diagonal elements
            var det: f32 = sign;
            for (0..temp.rows) |i| {
                det *= temp.contents[i][i];
            }

            return det;
        }

        /// Calculates the cofactor of a matrix element
        ///
        /// `row`: The row index of the element
        ///
        /// `col`: The column index of the element
        ///
        /// Returns: The cofactor value
        pub fn cofactor(self: *Matrix(rows, cols), row: usize, col: usize) !f32 {
            // The cofactor is the determinant of the submatrix obtained by removing the row and column of the element
            var contents: [rows - 1][cols - 1]f32 = undefined;
            for (0..rows) |i| {
                for (0..cols) |j| {
                    if (i == row or j == col) {
                        continue;
                    } else if (i > row and j > col) {
                        contents[i - 1][j - 1] = self.contents[i][j];
                    } else if (i > row) {
                        contents[i - 1][j] = self.contents[i][j];
                    } else if (j > col) {
                        contents[i][j - 1] = self.contents[i][j];
                    } else {
                        contents[i][j] = self.contents[i][j];
                    }
                }
            }

            var submatrix = try Matrix(rows - 1, cols - 1).init(self.allocator, contents);

            const det = try submatrix.determinant();
            return det.? * std.math.pow(f32, -1, @as(f32, @floatFromInt(row)) + @as(f32, @floatFromInt(col)));
        }

        /// Creates the transpose of this matrix
        ///
        /// Returns: A new matrix that is the transpose of this matrix
        pub fn transpose(self: *const Matrix(rows, cols)) !Matrix(cols, rows) {
            var contents: [cols][rows]f32 = undefined;

            // Initialize transposed matrix
            for (0..cols) |i| {
                for (0..rows) |j| {
                    contents[i][j] = self.contents[j][i];
                }
            }

            return Matrix(cols, rows).init(self.allocator, contents);
        }

        /// Calculates the inverse of this matrix
        ///
        /// Returns: A new matrix that is the inverse of this matrix, or `null` if the matrix is singular
        pub fn inverse(self: *Matrix(rows, cols)) !?Matrix(rows, cols) {
            // For a matrix to have an inverse, it must be square with a non-zero determinant
            const det = try self.determinant();
            if (!self.isSquare() or det == 0 or det == null) {
                return null;
            }

            // Compute the cofactor matrix at every entry
            var contents: [rows][cols]f32 = undefined;
            for (0..rows) |i| {
                for (0..cols) |j| {
                    contents[i][j] = try self.cofactor(i, j);
                }
            }

            // Transpose the cofactor matrix
            const cofactor_matrix = try Matrix(rows, cols).init(self.allocator, contents);
            const transposed = try cofactor_matrix.transpose();

            // Multiply by the reciprocal of the determinant
            var result_contents: [rows][cols]f32 = undefined;
            for (0..rows) |i| {
                for (0..cols) |j| {
                    result_contents[i][j] = transposed.contents[i][j] * (1 / det.?);
                }
            }

            const result = try Matrix(rows, cols).init(self.allocator, result_contents);
            return result;
        }
    };
}

/// Represents a plane in 3D space defined by a normal vector and a point
pub const Plane = struct {
    normal: rl.Vector3,
    p0: rl.Vector3,

    /// Creates a new plane from a normal vector and a point
    ///
    /// `normal`: The normal vector of the plane
    ///
    /// `p0`: A point on the plane
    ///
    /// Returns: A new plane
    pub fn init(normal: rl.Vector3, p0: rl.Vector3) Plane {
        return Plane{ .normal = normal, .p0 = p0 };
    }

    /// Projects a point onto the plane
    ///
    /// `point`: The point to project
    ///
    /// Returns: The projected point on the plane
    pub fn project(self: *Plane, point: rl.Vector3) rl.Vector3 {
        const v = point.subtract(self.p0);
        const adjustment_magnitude = rl.Vector3.dotProduct(v, self.normal) / rl.Vector3.dotProduct(self.normal, self.normal);
        return point.subtract(self.normal.scale(adjustment_magnitude));
    }
};

const ComparisonAxis = struct {
    root_point: *rl.Vector2,
    helper_point: *rl.Vector2,
};

fn comparator(context: ComparisonAxis, lhs: rl.Vector2, rhs: rl.Vector2) bool {
    const v1 = lhs.subtract(context.root_point);
    const v2 = rhs.subtract(context.root_point);

    const root_vec = context.root_point.subtract(context.helper_point);

    const c1 = root_vec.dotProduct(v1) / root_vec.dotProduct(root_vec); // Cosine between lhs and root
    const c2 = root_vec.dotProduct(v2) / root_vec.dotProduct(root_vec); // Cosine between rhs and root

    return c1 > c2; // Greater cosine means smaller angle
}

fn findRootPoint(points: []rl.Vector2) *rl.Vector2 {
    var min_index = 0;
    for (0..points.len) |i| {
        if (points[i].y < points[min_index].y) {
            min_index = i;
        }
        else if (points[i].y == points[min_index].y and points[i].x < points[min_index].x) {
            min_index = i;
        }
    }

    return &points[min_index];
}

pub fn sortPointsClockwise(points: []rl.Vector2) !void {
    // First get the root point
    const root_point = findRootPoint(points);
    const helper_point: rl.Vector2 = .{ .x = root_point.x - 1.0, .y = root_point.y };
    std.mem.sort(rl.Vector2, points, ComparisonAxis{ .helper_point = helper_point, .root_point = root_point }, comparator);
}

// As this is a more trivial test, a 2x2 matrix is all that's necessary (I hope)
test "matrix transform vector" {
    const alloc = std.testing.allocator;
    const contents = [_][2]f32{
        [_]f32{ 1, 2 },
        [_]f32{ 3, 4 },
    };

    const vector = [_]f32{ 1, 2 };
    const expected_result = [_]f32{ 1 * 1 + 2 * 2, 3 * 1 + 4 * 2 };

    var mat = try Matrix(2, 2).init(&alloc, contents);
    const result = try mat.transformVector(vector);
    defer alloc.free(result);

    // Compare the slices directly
    for (result, 0..) |val, i| {
        try std.testing.expect(std.math.approxEqAbs(f32, val, expected_result[i], 0.000001));
    }
}

// As this is a more trivial test, a 2x2 matrix is all that's necessary (I hope)
test "matrix multiplication" {
    const alloc = std.testing.allocator;
    const contents = [_][2]f32{
        [_]f32{ 1, 2 },
        [_]f32{ 3, 4 },
    };

    const other_contents = [_][2]f32{
        [_]f32{ 5, 6 },
        [_]f32{ 7, 8 },
    };

    const expected_contents = [_][2]f32{
        [_]f32{ 1 * 5 + 2 * 7, 1 * 6 + 2 * 8 },
        [_]f32{ 3 * 5 + 4 * 7, 3 * 6 + 4 * 8 },
    };

    var mat = try Matrix(2, 2).init(&alloc, contents);
    const expected_mat = try Matrix(2, 2).init(&alloc, expected_contents);
    var other_mat = try Matrix(2, 2).init(&alloc, other_contents);
    var result = try mat.matrixMultiply(2, 2, &other_mat);

    try std.testing.expect(result.equals(&expected_mat));
}

// Determinant values calculated using https://www.wolframalpha.com/, or by hand
test "matrix 2x2 determinant" {
    const alloc = std.testing.allocator;
    var contents = [_][2]f32{
        [_]f32{ 1, 2 },
        [_]f32{ 3, 4 },
    };

    var mat = try Matrix(2, 2).init(&alloc, contents);
    const det1 = try mat.determinant();
    try std.testing.expect(std.math.approxEqAbs(f32, det1.?, -2, 0.000001));

    contents = [_][2]f32{
        [_]f32{ 0.231, -1.123 },
        [_]f32{ 0.456, 0.789 },
    };

    mat.setContents(contents);
    const det2 = try mat.determinant();
    try std.testing.expect(std.math.approxEqAbs(f32, det2.?, 0.694347, 0.000001));
}

test "matrix 3x3 determinant" {
    const alloc = std.testing.allocator;
    var contents = [_][3]f32{
        [_]f32{ 1, 2, 3 },
        [_]f32{ 4, 5, 6 },
        [_]f32{ 7, 8, 9 },
    };

    var mat = try Matrix(3, 3).init(&alloc, contents);
    const det1 = try mat.determinant();
    try std.testing.expect(std.math.approxEqAbs(f32, det1.?, 0, 0.000001));

    contents = [_][3]f32{
        [_]f32{ 8.321, -0.142, 0.002 },
        [_]f32{ -10.890, 0.782, 0.003 },
        [_]f32{ 0.000, 0.666, 0.123 },
    };

    mat.setContents(contents);
    const det2 = try mat.determinant();
    try std.testing.expect(std.math.approxEqAbs(f32, det2.?, 0.579028, 0.000001));
}

test "matrix 4x4 determinant" {
    const alloc = std.testing.allocator;
    var contents = [_][4]f32{
        [_]f32{ 1, 2, 3, 4 },
        [_]f32{ 5, 6, 7, 8 },
        [_]f32{ 9, 10, 11, 12 },
        [_]f32{ 13, 14, 15, 16 },
    };

    var mat = try Matrix(4, 4).init(&alloc, contents);
    const det1 = try mat.determinant();
    try std.testing.expect(std.math.approxEqAbs(f32, det1.?, 0, 0.000001));

    contents = [_][4]f32{
        [_]f32{ 0.732, 0.143, 0.881, 0.550 },
        [_]f32{ 0.620, 0.458, 0.278, 0.716 },
        [_]f32{ 0.987, 0.104, 0.391, 0.204 },
        [_]f32{ 0.456, 0.791, 0.203, 0.918 },
    };

    mat.setContents(contents);
    const det2 = try mat.determinant();
    try std.testing.expect(std.math.approxEqAbs(f32, det2.?, 0.0609483, 0.000001));
}

test "matrix 5x5 determinant" {
    const alloc = std.testing.allocator;
    var contents = [_][5]f32{
        [_]f32{ 1, 2, 3, 4, 5 },
        [_]f32{ 6, 7, 8, 9, 10 },
        [_]f32{ 11, 12, 13, 14, 15 },
        [_]f32{ 16, 17, 18, 19, 20 },
        [_]f32{ 21, 22, 23, 24, 25 },
    };

    var mat = try Matrix(5, 5).init(&alloc, contents);
    const det1 = try mat.determinant();
    try std.testing.expect(std.math.approxEqAbs(f32, det1.?, 0, 0.000001));

    contents = [_][5]f32{
        [_]f32{ 2.314, -1.829, 4.576, -0.627, -3.912 },
        [_]f32{ -4.110, 1.273, -0.892, 3.601, 0.456 },
        [_]f32{ 2.881, -3.009, 0.004, 1.668, -2.333 },
        [_]f32{ -0.777, 4.822, 3.093, -4.365, 0.205 },
        [_]f32{ 1.678, -1.155, -3.783, 0.919, 2.540 },
    };

    mat.setContents(contents);
    const det2 = try mat.determinant();
    try std.testing.expect(std.math.approxEqAbs(f32, det2.?, 214.94, 0.001)); // Experimentally, this value makes sense for f32 and the size of determinant
}

test "matrix cofactor" {
    const alloc = std.testing.allocator;
    const contents = [_][3]f32{
        [_]f32{ 1, 2, 3 },
        [_]f32{ 4, 5, 6 },
        [_]f32{ 7, 8, 9 },
    };

    var mat = try Matrix(3, 3).init(&alloc, contents);

    // Test cofactor of element at (0,0)
    const cof00 = try mat.cofactor(0, 0);
    try std.testing.expect(std.math.approxEqAbs(f32, cof00, -3, 0.000001));

    // Test cofactor of element at (1,1)
    const cof11 = try mat.cofactor(1, 1);
    try std.testing.expect(std.math.approxEqAbs(f32, cof11, -12, 0.000001));

    // Test cofactor of element at (2,2)
    const cof22 = try mat.cofactor(2, 2);
    try std.testing.expect(std.math.approxEqAbs(f32, cof22, -3, 0.000001));
}

test "matrix transpose" {
    const alloc = std.testing.allocator;
    const contents = [_][3]f32{
        [_]f32{ 1, 2, 3 },
        [_]f32{ 4, 5, 6 },
        [_]f32{ 7, 8, 9 },
    };

    var mat = try Matrix(3, 3).init(&alloc, contents);
    const transposed = try mat.transpose();

    // Check that the transpose is correct
    try std.testing.expect(transposed.contents[0][0] == 1);
    try std.testing.expect(transposed.contents[0][1] == 4);
    try std.testing.expect(transposed.contents[0][2] == 7);
    try std.testing.expect(transposed.contents[1][0] == 2);
    try std.testing.expect(transposed.contents[1][1] == 5);
    try std.testing.expect(transposed.contents[1][2] == 8);
    try std.testing.expect(transposed.contents[2][0] == 3);
    try std.testing.expect(transposed.contents[2][1] == 6);
    try std.testing.expect(transposed.contents[2][2] == 9);
}

test "matrix inverse" {
    const alloc = std.testing.allocator;

    // Test with a non-invertible matrix (determinant = 0)
    const singular_contents = [_][2]f32{
        [_]f32{ 1, 2 },
        [_]f32{ 2, 4 },
    };
    var singular_mat = try Matrix(2, 2).init(&alloc, singular_contents);
    const inv1 = try singular_mat.inverse();
    try std.testing.expect(inv1 == null);

    // Test with an invertible matrix
    const contents = [_][2]f32{
        [_]f32{ 4, 7 },
        [_]f32{ 2, 6 },
    };
    var mat = try Matrix(2, 2).init(&alloc, contents);
    const inv2 = try mat.inverse();
    try std.testing.expect(inv2 != null);
    if (inv2) |inverse| {
        // The inverse of [4 7; 2 6] should be [0.6 -0.7; -0.2 0.4]
        try std.testing.expect(std.math.approxEqAbs(f32, inverse.contents[0][0], 0.6, 0.000001));
        try std.testing.expect(std.math.approxEqAbs(f32, inverse.contents[0][1], -0.7, 0.000001));
        try std.testing.expect(std.math.approxEqAbs(f32, inverse.contents[1][0], -0.2, 0.000001));
        try std.testing.expect(std.math.approxEqAbs(f32, inverse.contents[1][1], 0.4, 0.000001));
    }
}

test "matrix inverse multiplication" {
    const alloc = std.testing.allocator;
    const contents = [_][2]f32{
        [_]f32{ 4, 7 },
        [_]f32{ 2, 6 },
    };

    var mat = try Matrix(2, 2).init(&alloc, contents);
    const inv = try mat.inverse();
    try std.testing.expect(inv != null);
    if (inv) |inverse| {
        // Multiply matrix by its inverse
        const result = try mat.matrixMultiply(2, 2, &inverse);

        // The result should be the identity matrix
        try std.testing.expect(std.math.approxEqAbs(f32, result.contents[0][0], 1, 0.000001));
        try std.testing.expect(std.math.approxEqAbs(f32, result.contents[0][1], 0, 0.000001));
        try std.testing.expect(std.math.approxEqAbs(f32, result.contents[1][0], 0, 0.000001));
        try std.testing.expect(std.math.approxEqAbs(f32, result.contents[1][1], 1, 0.000001));
    }
}
