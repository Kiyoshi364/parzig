const std = @import("std");
const debug = std.debug;
const print = debug.print;

const P = @import("parser.zig");
const Parser = P.Parser;
const CharP = P.CharP;

pub fn main() !void {
    const stdin = std.io.getStdIn();

    const size = 0xFF;
    var buffer: [size]u8 = undefined;
    print("reading: ", .{});

    // Ignoring <CR><LF>
    const read = (try stdin.read(&buffer)) - 2;
    const input = buffer[0..read];

    print("input({}): {s}<LF>\n", .{ read, input });

    const p = P.StringP.init("something");
    const ret = p.parser.parse(input).data catch |err| {
        print("parser failed: {}\n", .{ err });
        return;
    };
    print("parsed: ({s}, {s})\n", .{ ret.val, ret.rest });
}
