const std = @import("std");

// TODO
// std.debug.prints -> std.log (some of them at least)
// better error msgs
// try to improve performance

fn printHelp() void {
    std.debug.print("zxd - Zig Hex Dump\n", .{});
    std.debug.print("\nUsage: zxd <command> <args>\n", .{});
    std.debug.print("\nCommands:\n", .{});
    std.debug.print("  help:    Prints this message. Takes no args.\n", .{});
    std.debug.print("  dump:    Dumps a binary file. Takes the file as argument.\n", .{});
    std.debug.print("           You can also add the bytes per row.\n", .{});
}

fn dump(buffer: []const u8, bytes_per_row: u32) void {
    // Legend
    std.debug.print("  Offset ", .{});
    for (0..bytes_per_row) |i| {
        std.debug.print(" {X:0>2} ", .{i});
    }

    // Full rows
    const full_rows = buffer.len / bytes_per_row;
    for (0..full_rows) |row| {
        const offset = row * bytes_per_row;
        std.debug.print("\n{X:0>8} ", .{offset});

        // Hex data
        for (0..bytes_per_row) |i| {
            std.debug.print(" {X:0>2} ", .{buffer[offset + i]});
        }

        std.debug.print("    ", .{});

        // Ascii
        for (0..bytes_per_row) |i| {
            const byte = buffer[offset + i];
            if (std.ascii.isPrint(byte)) {
                std.debug.print("{c}", .{byte});
            } else {
                std.debug.print(".", .{});
            }
        }
    }

    // Possible remaining row
    if (buffer.len % bytes_per_row == 0) return; // we finished
    const remaining_bytes = buffer.len - (full_rows * bytes_per_row);
    const offset = full_rows * bytes_per_row;
    std.debug.print("\n{X:0>8} ", .{offset});

    // Hex data
    for (0..bytes_per_row) |i| {
        if (i < remaining_bytes) {
            std.debug.print(" {X:0>2} ", .{buffer[offset + i]});
        } else {
            std.debug.print("    ", .{});
        }
    }

    std.debug.print("    ", .{});

    // Ascii
    for (0..remaining_bytes) |i| {
        const byte = buffer[offset + i];
        if (std.ascii.isPrint(byte)) {
            std.debug.print("{c}", .{byte});
        } else {
            std.debug.print(".", .{});
        }
    }
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    var args = std.process.argsWithAllocator(allocator) catch |err| {
        std.debug.print("Could not get args: {s}\n", .{@errorName(err)});
        std.process.exit(1);
    };
    defer args.deinit();

    // Skip executable
    _ = args.skip();

    const command = args.next();
    if (command == null) {
        printHelp();
        std.process.exit(0);
    }

    if (std.mem.eql(u8, command.?, "dump")) {
        const file_path = args.next();
        if (file_path == null) {
            std.debug.print("ERROR: Expected filepath argument.\n\n", .{});
            printHelp();
            std.process.exit(0);
        }

        const bytes_per_row_str = args.next();
        var bytes_per_row: u32 = undefined;
        if (bytes_per_row_str) |s| {
            bytes_per_row = std.fmt.parseInt(u32, s, 10) catch |err| blk: {
                std.debug.print("ERROR: Failed to parse arg '{s}' as a number. Error '{s}'. Setting bytes per row to default (16).\n", .{ s, @errorName(err) });
                break :blk 16;
            };
        } else {
            bytes_per_row = 16;
        }

        const file: std.fs.File = std.fs.cwd().openFile(file_path.?, .{}) catch |err| {
            std.debug.print("ERROR: Could not open file at '{s}'. Error '{s}'.\n", .{ file_path.?, @errorName(err) });
            std.process.exit(1);
        };
        defer file.close();

        const file_size = try file.getEndPos();
        std.debug.print("File length: {d}\n", .{file_size});

        const buffer = try allocator.alloc(u8, file_size);
        defer allocator.free(buffer);
        _ = try file.read(buffer);

        dump(buffer, bytes_per_row);
    } else if (std.mem.eql(u8, command.?, "help")) {
        printHelp();
    } else {
        std.debug.print("ERROR: Unknown command.\n\n", .{});
        printHelp();
    }

    std.debug.print("\n", .{});
}
