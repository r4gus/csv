const Csv = @import("main.zig").Csv;
const Row = @import("main.zig").Row;
const std = @import("std");

// /////////////////////////////////////////
// C interface                          ////
// /////////////////////////////////////////

// TODO: use this in conjunction with a error function
var csv_error: ?[:0]const u8 = null;

export fn csv_open(path: [*c]const u8) ?*anyopaque {
    var x = Csv.open(path[0..strlen(path)], std.heap.c_allocator) catch {
        return null;
    };

    var y = std.heap.c_allocator.create(Csv) catch {
        return null;
    };

    y.* = x;
    return @ptrCast(y);
}

export fn csv_close(self: *anyopaque) void {
    var csv: *Csv = @ptrCast(@alignCast(self));
    csv.close();
    std.heap.c_allocator.destroy(csv);
}

export fn csv_write(self: *anyopaque, path: [*c]const u8) i32 {
    var csv: *Csv = @ptrCast(@alignCast(self));
    const p = if (path != 0) path[0..strlen(path)] else null;
    csv.write(.{ .path = p }) catch {
        return -1;
    };

    return 0;
}

export fn csv_next(self: *anyopaque) ?*anyopaque {
    var csv: *Csv = @ptrCast(@alignCast(self));

    var r = csv.next();
    if (r == null) return null;

    var y = std.heap.c_allocator.create(Row) catch {
        return null;
    };

    y.* = r.?;
    return @ptrCast(y);
}

export fn csv_reset(self: *anyopaque) void {
    var csv: *Csv = @ptrCast(@alignCast(self));
    csv.reset();
}

export fn csv_set(self: *anyopaque, index: usize, v: [*c]const u8, len: usize) i32 {
    var csv: *Csv = @ptrCast(@alignCast(self));
    csv.set(index, v[0..len]) catch {
        return -1;
    };
    return 0;
}

export fn csv_append(self: *anyopaque, v: [*c]const u8, len: usize) i32 {
    var csv: *Csv = @ptrCast(@alignCast(self));
    csv.append(v[0..len]) catch {
        return -1;
    };
    return 0;
}

export fn csv_row_next(self: *anyopaque, len: *usize) [*c]const u8 {
    var row: *Row = @ptrCast(@alignCast(self));
    if (row.next()) |c| {
        len.* = c.len;
        return c.ptr;
    } else {
        return null;
    }
}

inline fn strlen(s: [*c]const u8) usize {
    var len: usize = 0;
    while (s[len] != 0) : (len += 1) {}
    return len;
}
