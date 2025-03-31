const rl = @import("raylib");
const std = @import("std");

pub const MatrixConstructionError = error{
    InvalidSize,
    InvalidShape,
};

pub const Matrix = struct {
    allocator: *std.mem.Allocator,

    rows: usize,
    cols: usize,
    contents: [][]f32,

    /// Takes ownership if the contents, deinit must be called to free the memory
    pub fn init(allocator: *std.mem.Allocator, contents: [][]f32) MatrixConstructionError!Matrix {
        if (contents.len == 0) {
            return MatrixConstructionError.InvalidSize;
        }

        const row_size = contents[0].len;

        for (contents) |row| {
            if (row.len != row_size) {
                return MatrixConstructionError.InvalidShape;
            }
        }

        return Matrix{
            .allocator = allocator,
            .rows = contents.len,
            .cols = contents[0].len,
            .contents = contents,
        };
    }

    pub fn deinit(self: *Matrix) void {
        self.allocator.destroy(self.contents);
    }

    /// Creates a new vector that is transformed based on the called matrix
    /// It is on the caller of this function to free the memory
    pub fn transformVector(self: *Matrix, vector: []f32) ![]f32 {
        if (vector.len != self.cols) {
            return error.InvalidSize;
        }

        var result = try self.allocator.alloc(f32, vector.len);
        errdefer {
            self.allocator.free(result);
        }

        for (0..self.cols) |i| {
            const row = self.contents[i];
            result[i] = 0;
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
    pub fn matrixMultiply(self: *Matrix, other: *Matrix) !*Matrix {
        if (self.rows != other.cols) {
            return error.MismatchedShapes;
        }

        var new_contents = try self.allocator.alloc([]f32, self.rows);
        errdefer {
            for (new_contents) |row| {
                self.allocator.free(row);
            }
            self.allocator.free(new_contents);
        }

        for (0..self.rows) |i| {
            new_contents[i] = try self.allocator.alloc(f32, other.cols);
            for (0..other.cols) |j| {
                var sum: f32 = 0;
                for (0..self.cols) |k| {
                    sum += self.contents[i][k] * other.contents[k][j];
                }
                new_contents[i][j] = sum;
            }
        }

        var result = try Matrix.init(self.allocator, new_contents);
        return &result;
    }

    pub fn isSquare(self: *Matrix) bool {
        return self.rows == self.cols;
    }

    /// Use Gaussian elimination to find the determinant in O(n^3) time. 
    /// We can use Gaussian elimination because certain properties of the matrix will be preserved if we only use fundamental operations. 
    /// I can't explain exactly why rows can be added and multiplied and what not, but how that matrix changes some input vector will fundamentally not change
    /// 
    /// As we live in the real world, we must round these values (f32 precision) and so it's guaranteed that precision will be lost, and perhaps for large enough matrices
    /// it will not be accurate enough to do anything meaningful with the result
    pub fn determinant(self: *Matrix) !?f32 {
        if (!self.isSquare()) {
            return;
        }

        var temp = try Matrix.init(self.allocator, self.contents);
        defer temp.deinit();

        for (1..temp.rows) |i| {
            const r1 = temp.contents[i];
            for (0..i) |j| {
                const r2 = temp.contents[j];
                const scale_factor = r2[j] / r1[j];

                // Scale r2
                for (r2) |*val| {
                    val.* *= scale_factor;
                }

                for (r1, r2) |*val1, *val2| {
                    val1.* -= val2.*;
                }
            }

            temp[i] = r1;
        }

        var res: f32 = 1;
        for (temp.rows) |i| {
            res *= temp.contents[i][i];
        }

        return res;
    }
};