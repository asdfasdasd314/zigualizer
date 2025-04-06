const rl = @import("raylib");
const std = @import("std");

pub const MatrixConstructionError = error{
    InvalidSize,
    InvalidShape,
};

pub fn Matrix(comptime rows: usize, comptime cols: usize) type {
    return struct {
        allocator: *const std.mem.Allocator,

        comptime rows: usize = rows,
        comptime cols: usize = cols,
        contents: [rows][cols]f32,

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

        pub fn setContents(self: *Matrix(rows, cols), contents: [rows][cols]f32) void {
            self.contents = contents;
        }

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

        /// Creates a new vector that is transformed based on the called matrix
        /// It is on the caller of this function to free the memory
        pub fn transformVector(self: *Matrix(rows, cols), vector: [cols]f32) ![]f32 {
            if (vector.len != self.cols) {
                return error.InvalidSize;
            }

            var result = try self.allocator.alloc(f32, vector.len);
            @memset(result, 0);

            for (0..self.rows) |i| {
                const row = self.contents[i];
                for (row, vector) |v1, v2| {
                    result[i] += v1 * v2;
                }
            }

            return result;
        }

        /// Applies the `other` matrix to the first matrix like this:
        ///
        /// `self = A`, `other = B`
        ///
        /// `self.applyMatrix(other) = AB`
        ///
        /// It is on the caller of this function to free the memory
        pub fn matrixMultiply(
            self: *Matrix(rows, cols),
            comptime other_rows: usize,
            comptime other_cols: usize,
            other: *Matrix(other_rows, other_cols),
        ) !*Matrix(rows, other_cols) {
            if (self.cols != other.rows) {
                return error.MismatchedShapes;
            }

            // First create the result matrix with undefined contents
            const new_mat = try other.allocator.create(Matrix(rows, other_cols));
            errdefer other.allocator.destroy(new_mat);

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

            // Initialize the matrix with our computed contents
            new_mat.* = try Matrix(rows, other_cols).init(other.allocator, contents);
            return new_mat;
        }

        pub fn isSquare(self: *Matrix(rows, cols)) bool {
            return self.rows == self.cols;
        }

        /// Use Gaussian elimination to find the determinant in O(n^3) time.
        /// We can use Gaussian elimination because certain properties of the matrix will be preserved if we only use fundamental operations.
        /// I can't explain exactly why rows can be added and multiplied and what not, but how that matrix changes some input vector will fundamentally not change
        ///
        /// As we live in the real world, we must round these values (f32 precision) and so it's guaranteed that precision will be lost, and perhaps for large enough matrices
        /// it will not be accurate enough to do anything meaningful with the result
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

        pub fn inverse(self: *Matrix(rows, cols)) !*Matrix(rows, cols) {
            if (!self.isSquare()) {
                return null;
            }
            
                
        }
    };
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

    try std.testing.expect(std.mem.eql(f32, result, &expected_result));
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
    defer alloc.destroy(result);

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
