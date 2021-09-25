const std = @import("std");
const Alloc = std.mem.Allocator;

pub fn parseFunc(comptime T: type) type {
    return fn(self: *const Parser(T), input: []const u8) MaybeParsed(T);
}

pub fn Parser(comptime Val: type) type {
    return struct {
        const Self = @This();

        parseFn: parseFunc(Val),

        pub fn parse(self: *const Self, input: []const u8) MaybeParsed(Val) {
            return self.parseFn(self, input);
        }
    };
}

pub fn MaybeParsed(comptime Val: type) type {
    return union {
        data: ParserErr!Parsed(Val),
    };
}

pub fn Parsed(comptime Val: type) type {
    return struct {
        val: Val,
        rest: []const u8,
    };
}

pub const ParserErr = error {
    ParserFailed
};

// building blocks

pub fn FailP(comptime T: type) type {
    return struct {
        parser: Parser(T),

        pub fn init() @This() {
            return .{ .parser = .{ .parseFn = fail } };
        }

        fn fail(parser: *const Parser(T), input: []const u8) MaybeParsed(T) {
            _ = parser; _ = input;
            return .{ .data = ParserErr.ParserFailed };
        }
    };
}

pub const CharP = struct {

    char: u8,
    parser: Parser(u8),

    pub fn init(char: u8) @This() {
        return .{ .char = char, .parser = .{ .parseFn = charp } };
    }

    fn charp(parser: *const Parser(u8), input: []const u8) MaybeParsed(u8) {
        const char = @fieldParentPtr(@This(), "parser", parser).char;
        if ( input.len < 1 or input[0] != char ) {
            return .{ .data = ParserErr.ParserFailed };
        }
        return .{ .data = .{
            .val = char,
            .rest = input[1..],
        }};
    }
};

pub fn SequenceP(comptime T: type, comptime n: comptime_int) type {
    return struct {
        parsers: [n]*const Parser(T),
        parser: Parser([n]T),

        pub fn init(parsers: [n]*const Parser(T)) @This() {
            return .{ .parsers = parsers, .parser = .{ .parseFn = seqp } };
        }

        fn seqp(parser: *const Parser([n]T), input: []const u8) MaybeParsed([n]T) {
            const self = @fieldParentPtr(@This(), "parser", parser);
            var values: [n]T = undefined;
            var curr_in = input;
            for (self.parsers) |p, i| {
                const res = p.parse(curr_in).data catch
                    return .{ .data = ParserErr.ParserFailed };
                curr_in = res.rest;
                values[i] = res.val;
            }
            return .{ .data = .{
                    .val = values,
                    .rest = curr_in,
                }};
        }
    };
}

pub fn StringP(comptime n: comptime_int) type {
    return struct {
        str: []const u8,
        parser: Parser([n]u8),

        pub fn init(str: []const u8) @This() {
            @import("std").debug.assert(str.len <= n);
            return .{ .str = str, .parser = .{ .parseFn = strp } };
        }

        fn strp(parser: *const Parser([n]u8), input: []const u8) MaybeParsed([n]u8) {
            const self = @fieldParentPtr(@This(), "parser", parser);
            const charPs: [n]CharP = blk: {
                var _charPs: [n]CharP = undefined;
                for (self.str) |char, i| {
                    _charPs[i] = CharP.init(char);
                }
                break :blk _charPs;
            };

            const parsers: [n]*const Parser(u8) = blk: {
                var parsers: [n]*const Parser(u8) = undefined;
                for (charPs) |*charP, i| {
                   parsers[i] = &charP.parser;
                }
                break :blk parsers;
            };

            return SequenceP(u8, n).init(parsers).parser.parse(input);
        }

    };
}
