pub fn ParseFunc(comptime T: type) type {
    return fn(self: *const Parser(T), input: []const u8) MaybeParsed(T);
}

pub fn Parser(comptime Val: type) type {
    return struct {
        const Self = @This();

        parseFn: ParseFunc(Val),

        pub fn parse(self: *const Self, input: []const u8) MaybeParsed(Val) {
            return self.parseFn(self, input);
        }

        pub fn fmap(self: *const Self, comptime T: type, func: fn(Val) T) MappedP(Val, T) {
            return MappedP(Val, T).init(func, self);
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
            return .{ .parser = .{ .parseFn = failp } };
        }

        fn failp(parser: *const Parser(T), input: []const u8) MaybeParsed(T) {
            _ = parser; _ = input;
            return .{ .data = ParserErr.ParserFailed };
        }
    };
}

pub const PureP = ConstP;
pub fn ConstP(comptime T: type) type {
    return struct {
        thing: T,
        parser: Parser(T),

        pub fn init(thing: T) @This() {
            return .{ .thing = thing, .parser = .{ .parseFn = constp } };
        }

        fn constp(parser: *const Parser(T), input: []const u8) MaybeParsed(T) {
            const thing = @fieldParentPtr(@This(), "parser", parser).thing;
            return .{ .data = .{ .val = thing, .rest = input } };
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
        return .{ .data = .{ .val = char, .rest = input[1..], }};
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
            return .{ .data = .{ .val = values, .rest = curr_in }};
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

pub const WhileTrueP = ScanP;
pub const ScanP = struct {
    pred: fn(u8) bool,
    parser: Parser([]const u8),

    pub fn init(pred: fn(u8) bool) @This() {
        return .{ .pred = pred, .parser = .{ .parseFn = scanp } };
    }

    fn scanp(parser: *const Parser([]const u8), input: []const u8) MaybeParsed([]const u8) {
        const pred = @fieldParentPtr(@This(), "parser", parser).pred;
        for (input) |char, i| {
            if ( !pred(char) )
                return .{ .data = .{ .val = input[0..i], .rest = input[i..] } };
        } else {
            return .{ .data = .{ .val = input[0..], .rest = "" } };
        }
    }
};

pub fn MappedP(comptime A: type, comptime B: type) type {
    return struct {
        func: fn(A) B,
        base: *const Parser(A),
        parser: Parser(B),

        pub fn init(func: fn(A) B, base: *const Parser(A)) @This() {
            return .{ .func = func, .base = base,
                .parser = .{ .parseFn = mappedp } };
        }

        fn mappedp(parser: *const Parser(B), input: []const u8) MaybeParsed(B) {
            const self = @fieldParentPtr(@This(), "parser", parser);
            const ret = self.base.parse(input).data catch |err|
                return .{ .data = err };
            const b = self.func(ret.val);
            return .{ .data = .{ .val = b, .rest = ret.rest } };
        }
    };
}

pub fn AppliedP(comptime A: type, comptime B: type) type {
    return AppliedP2(A, B, 2);
}
pub fn AppliedP2(comptime A: type, comptime B: type, comptime config: comptime_int) type {
    return struct {
        funcp: *const Parser(fn(A) B),
        base: *const Parser(A),
        parser: Parser(B),

        pub fn init(funcp: *const Parser(fn(A) B), base: *const Parser(A)) @This() {
            return .{ .funcp = funcp, .base = base,
                .parser = .{ .parseFn = appliedp } };
        }

        fn appliedp(parser: *const Parser(B), input: []const u8) MaybeParsed(B) {
            const self = @fieldParentPtr(@This(), "parser", parser);
            const ret = self.funcp.parse(input).data catch |err|
                return .{ .data = err };
            switch ( config ) {
                // fmap: Stack Overflow
                0 => {
                    const newparser = self.base.fmap(B, ret.val).parser;
                    return newparser.parse(ret.rest);
                },
                // inlining fmap: Stack Overflow
                1 => {
                    const mapped = MappedP(A, B).init(ret.val, self.base);
                    const newparser = mapped.parser;
                    return newparser.parse(ret.rest);
                },
                // inlining MappedP
                2 => {
                    const ret2 = self.base.parse(ret.rest).data catch |err|
                        return .{ .data = err };
                    const b = ret.val(ret2.val);
                    return .{ .data = .{ .val = b, .rest = ret2.rest } };
                },
                else => @compileError("invalid option for AppliedP2"),
            }
        }
    };
}
