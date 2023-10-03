const std = @import("std");
const testing = std.testing;

pub const Csv = struct {
    file: std.fs.File,
    buffer: []u8,
    rows: std.mem.SplitIterator(u8, .any),
    index: usize = 0,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn open(path: []const u8, allocator: std.mem.Allocator) !Self {
        var f = try std.fs.cwd().openFile(path, .{ .mode = .read_write });
        errdefer f.close();
        var b = try f.readToEndAlloc(allocator, 5_000_000);
        errdefer allocator.free(b);
        var r = std.mem.splitAny(u8, b, "\n");

        return .{
            .file = f,
            .buffer = b,
            .rows = r,
            .allocator = allocator,
        };
    }

    pub fn close(self: *Self) void {
        self.file.close();
        self.allocator.free(self.buffer);
    }

    pub fn write(self: *Self, options: struct { path: ?[]const u8 = null }) !void {
        if (options.path) |path| {
            var f = std.fs.cwd().openFile(path, .{ .mode = .read_write }) catch blk: {
                break :blk try std.fs.cwd().createFile(path, .{});
            };
            defer f.close();
            try f.writeAll(self.buffer);
        } else {
            try self.file.writeAll(self.buffer);
        }
    }

    pub fn next(self: *Self) ?Row {
        if (self.rows.next()) |r| {
            self.index += 1;
            return .{
                .buffer = r,
                .cols = std.mem.splitAny(u8, r, ","),
            };
        } else {
            return null;
        }
    }

    pub fn reset(self: *Self) void {
        self.rows.reset();
        self.index = 0;
    }

    pub fn set(self: *Self, index: usize, row: []const u8) !void {
        self.rows.reset();
        var arr = std.ArrayList(u8).init(self.allocator);
        var j: usize = 0;
        errdefer {
            arr.deinit();
            j = 0;
            while (j < self.index) : (j += 1) {
                _ = self.rows.next();
            }
        }
        var writer = arr.writer();

        var valid = false;
        while (self.rows.next()) |r| {
            if (index == j) {
                try writer.writeAll(row);
                valid = true;
            } else {
                try writer.writeAll(r);
            }
            if (arr.getLast() != '\n') {
                try writer.writeByte('\n');
            }
            j += 1;
        }

        // Get the iterator into its original state

        if (!valid) {
            return error.IndexOutOfBounds;
        }

        var b = self.buffer;
        errdefer self.buffer = b;

        var b2 = try arr.toOwnedSlice();
        self.allocator.free(self.buffer); // invalidates b
        self.buffer = b2;
        self.rows = std.mem.splitAny(u8, self.buffer, "\n");
    }

    pub fn append(self: *Self, row: []const u8) !void {
        const len = self.buffer.len;
        self.buffer = try self.allocator.realloc(self.buffer, len + row.len);
        @memcpy(self.buffer[len..], row);

        self.index = 0;
        self.rows = std.mem.splitAny(u8, self.buffer, "\n");
    }
};

pub const Row = struct {
    buffer: []const u8,
    cols: std.mem.SplitIterator(u8, .any),
    index: usize = 0,

    const Self = @This();

    pub fn next(self: *Self) ?[]const u8 {
        if (self.cols.next()) |c| {
            self.index += 1;
            return c;
        } else {
            return null;
        }
    }
};

test "read csv file #1" {
    var f = try Csv.open("examples/file1.csv", testing.allocator);
    defer f.close();

    var r1 = f.next();
    try testing.expect(r1 != null); // must not be null
    try testing.expectEqualStrings("Name", r1.?.next().?);
    try testing.expectEqualStrings("FirstName", r1.?.next().?);
    try testing.expectEqualStrings("Age", r1.?.next().?);

    var r2 = f.next();
    try testing.expect(r2 != null); // must not be null
    try testing.expectEqualStrings("Sugar", r2.?.next().?);
    try testing.expectEqualStrings("David", r2.?.next().?);
    try testing.expectEqualStrings("31", r2.?.next().?);

    var r3 = f.next();
    try testing.expect(r3 != null); // must not be null
    try testing.expectEqualStrings("Mustermann", r3.?.next().?);
    try testing.expectEqualStrings("Max", r3.?.next().?);
    try testing.expectEqualStrings("23", r3.?.next().?);
}

test "update csv data #1" {
    var f = try Csv.open("examples/file1.csv", testing.allocator);
    defer f.close();

    try f.set(1, "Sugar,Pierre,45");

    var r1 = f.next();
    try testing.expect(r1 != null); // must not be null
    try testing.expectEqualStrings("Name", r1.?.next().?);
    try testing.expectEqualStrings("FirstName", r1.?.next().?);
    try testing.expectEqualStrings("Age", r1.?.next().?);

    var r2 = f.next();
    try testing.expect(r2 != null); // must not be null
    try testing.expectEqualStrings("Sugar", r2.?.next().?);
    try testing.expectEqualStrings("Pierre", r2.?.next().?);
    try testing.expectEqualStrings("45", r2.?.next().?);

    var r3 = f.next();
    try testing.expect(r3 != null); // must not be null
    try testing.expectEqualStrings("Mustermann", r3.?.next().?);
    try testing.expectEqualStrings("Max", r3.?.next().?);
    try testing.expectEqualStrings("23", r3.?.next().?);
}

test "write data to file #1" {
    var f = try Csv.open("examples/file1.csv", testing.allocator);
    defer f.close();

    try f.set(1, "Sugar,Pierre,45");

    try f.write(.{ .path = "examples/tmp.csv" });
    var f2 = try Csv.open("examples/tmp.csv", testing.allocator);
    defer f2.close();

    var r1 = f2.next();
    try testing.expect(r1 != null); // must not be null
    try testing.expectEqualStrings("Name", r1.?.next().?);
    try testing.expectEqualStrings("FirstName", r1.?.next().?);
    try testing.expectEqualStrings("Age", r1.?.next().?);

    var r2 = f2.next();
    try testing.expect(r2 != null); // must not be null
    try testing.expectEqualStrings("Sugar", r2.?.next().?);
    try testing.expectEqualStrings("Pierre", r2.?.next().?);
    try testing.expectEqualStrings("45", r2.?.next().?);

    var r3 = f2.next();
    try testing.expect(r3 != null); // must not be null
    try testing.expectEqualStrings("Mustermann", r3.?.next().?);
    try testing.expectEqualStrings("Max", r3.?.next().?);
    try testing.expectEqualStrings("23", r3.?.next().?);
}

test "append row to data #1" {
    var f = try Csv.open("examples/file1.csv", testing.allocator);
    defer f.close();

    try f.append("Sugar,Pierre,45");

    var r1 = f.next();
    try testing.expect(r1 != null); // must not be null
    try testing.expectEqualStrings("Name", r1.?.next().?);
    try testing.expectEqualStrings("FirstName", r1.?.next().?);
    try testing.expectEqualStrings("Age", r1.?.next().?);

    var r2 = f.next();
    try testing.expect(r2 != null); // must not be null
    try testing.expectEqualStrings("Sugar", r2.?.next().?);
    try testing.expectEqualStrings("David", r2.?.next().?);
    try testing.expectEqualStrings("31", r2.?.next().?);

    var r3 = f.next();
    try testing.expect(r3 != null); // must not be null
    try testing.expectEqualStrings("Mustermann", r3.?.next().?);
    try testing.expectEqualStrings("Max", r3.?.next().?);
    try testing.expectEqualStrings("23", r3.?.next().?);

    var r4 = f.next();
    try testing.expect(r4 != null); // must not be null
    try testing.expectEqualStrings("Sugar", r4.?.next().?);
    try testing.expectEqualStrings("Pierre", r4.?.next().?);
    try testing.expectEqualStrings("45", r4.?.next().?);
}
