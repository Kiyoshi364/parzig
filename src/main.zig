const std = @import("std");
const debug = std.debug;
const print = debug.print;

const parzig = @import("parzig.zig");
const Parser = parzig.Parser;
const blocks = parzig.blocks;
const combi = parzig.combinators;
const CharP = blocks.CharP;
const SpanP = blocks.SpanP;

fn isLower(c: u8) bool { return 'a' <= c and c <= 'z'; }
fn length(xs: []const u8) usize { return xs.len; }

pub fn main() !void {
    const stdin = std.io.getStdIn();

    const size = 0xFF;
    var buffer: [size]u8 = undefined;
    print("reading: ", .{});

    // Ignoring <CR><LF>
    const trim = if (std.builtin.os.tag == .windows) 2 else 1;
    const read = (try stdin.read(&buffer)) - trim;
    const input = parzig.Input{ .str = buffer[0..read] };

    print("input({}): {s}<LF>\n", .{ read, input.str });

    const p = comptime blk: {
        const quote = CharP.init('"');
        const lower = SpanP.init(isLower);
        break :blk
            quote.parser.skip([]const u8,
                &(lower.parser.keep(u8,
                &(quote.parser))).parser
            ).parser
            .map(length);
    };

    switch ( p.parser.parse(input) ) {
        .err => |err| print("parser failed on pos {d}\n", .{ err.pos + 1 }),
        .data => |data| print("parsed: ({d}, {s})\n",
                .{ data.val, data.rest.str }),
    }
}
