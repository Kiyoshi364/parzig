const std = @import("std");
const debug = std.debug;
const print = debug.print;

const P = @import("parser.zig");
const Parser = P.Parser;
const blocks = P.blocks;
const CharP = blocks.CharP;
const SpanP = blocks.SpanP;

fn isLower(c: u8) bool { return 'a' <= c and c <= 'z'; }

pub fn main() !void {
    const stdin = std.io.getStdIn();

    const size = 0xFF;
    var buffer: [size]u8 = undefined;
    print("reading: ", .{});

    // Ignoring <CR><LF>
    const read = (try stdin.read(&buffer)) - 2;
    const input = P.Input{ .str = buffer[0..read] };

    print("input({}): {s}<LF>\n", .{ read, input.str });

    const quote = CharP.init('"');
    const lower = SpanP.init(isLower);

    const p = quote.parser.skip([]const u8,
              &(lower.parser.keep(u8,
              &(quote.parser))).parser
            );

    switch ( p.parser.parse(input) ) {
        .err => |err| print("parser failed on pos {d}\n", .{ err.pos + 1 }),
        .data => |data| print("parsed: ({s}, {s})\n",
                .{ data.val, data.rest.str }),
    }
}
