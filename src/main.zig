const std = @import("std");

// TODO
// better error msgs
// better args
// colored output
// try to improve performance

fn printHelp(writer: anytype) void {
    writer.print("zxd - Zig Hex Dump\n", .{}) catch unreachable;
    writer.print("\nUsage: zxd <command> [options]\n", .{}) catch unreachable;
    writer.print("\nCommands:\n", .{}) catch unreachable;
    writer.print("  help:                   Prints this message. Takes no args.\n", .{}) catch unreachable;
    writer.print("  dump <file> [width]:    Dumps a binary file. Takes the file as argument.\n", .{}) catch unreachable;
}

fn dump(buffer: []const u8, bytes_per_row: u32, writer: anytype) !void {
    // Legend
    try writer.print("  Offset ", .{});
    for (0..bytes_per_row) |i| {
        try writer.print(" {X:0>2} ", .{i});
    }

    // Full rows
    const full_rows = buffer.len / bytes_per_row;
    for (0..full_rows) |row| {
        const offset = row * bytes_per_row;
        try writer.print("\n{X:0>8} ", .{offset});

        // Hex data
        for (0..bytes_per_row) |i| {
            try writer.print(" {X:0>2} ", .{buffer[offset + i]});
        }

        try writer.print("    ", .{});

        // Ascii
        for (0..bytes_per_row) |i| {
            const byte = buffer[offset + i];
            if (std.ascii.isPrint(byte)) {
                try writer.print("{c}", .{byte});
            } else {
                try writer.print(".", .{});
            }
        }
    }

    // Possible remaining row
    if (buffer.len % bytes_per_row == 0) return; // we finished
    const remaining_bytes = buffer.len - (full_rows * bytes_per_row);
    const offset = full_rows * bytes_per_row;
    try writer.print("\n{X:0>8} ", .{offset});

    // Hex data
    for (0..bytes_per_row) |i| {
        if (i < remaining_bytes) {
            try writer.print(" {X:0>2} ", .{buffer[offset + i]});
        } else {
            try writer.print("    ", .{});
        }
    }

    try writer.print("    ", .{});

    // Ascii
    for (0..remaining_bytes) |i| {
        const byte = buffer[offset + i];
        if (std.ascii.isPrint(byte)) {
            try writer.print("{c}", .{byte});
        } else {
            try writer.print(".", .{});
        }
    }
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const stdout = std.io.getStdOut().writer();

    var args = std.process.argsWithAllocator(allocator) catch |err| {
        std.log.err("Failed to get args: {s}\n", .{@errorName(err)});
        std.process.exit(1);
    };
    defer args.deinit();

    // Skip executable
    _ = args.skip();

    const command = args.next();
    if (command == null) {
        printHelp(stdout);
        std.process.exit(0);
    }

    if (std.mem.eql(u8, command.?, "dump")) {
        const file_path = args.next();
        if (file_path == null) {
            std.log.err("Expected filepath argument.\n", .{});
            printHelp(stdout);
            std.process.exit(0);
        }

        const bytes_per_row_str = args.next();
        var bytes_per_row: u32 = undefined;
        if (bytes_per_row_str) |s| {
            bytes_per_row = std.fmt.parseInt(u32, s, 10) catch |err| blk: {
                std.log.err("Failed to parse arg '{s}' as a number. Error '{s}'. Setting bytes per row to default (16).\n", .{ s, @errorName(err) });
                break :blk 16;
            };
        } else {
            bytes_per_row = 16;
        }

        const file: std.fs.File = std.fs.cwd().openFile(file_path.?, .{}) catch |err| {
            std.log.err("Could not open file at '{s}'. Error '{s}'.\n", .{ file_path.?, @errorName(err) });
            std.process.exit(1);
        };
        defer file.close();

        const file_size = try file.getEndPos();
        try stdout.print("File length: {d}\n", .{file_size});

        const buffer = try allocator.alloc(u8, file_size);
        defer allocator.free(buffer);
        _ = try file.read(buffer);

        try dump(buffer, bytes_per_row, stdout);
    } else if (std.mem.eql(u8, command.?, "help")) {
        printHelp(stdout);
        std.process.exit(0);
    } else {
        std.log.err("Unknown command.\n", .{});
        printHelp(stdout);
        std.process.exit(0);
    }

    std.debug.print("\n", .{});
}
