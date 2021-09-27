const parzig = @import("parzig.zig");
const Parser = parzig.Parser;
const MaybeParsed = parzig.MaybeParsed;
const Input = parzig.Input;

pub fn FailP(comptime T: type) type {
    return struct {
        parser: Parser(T),

        pub fn init() @This() {
            return .{ .parser = .{ .parseFn = parserFn } };
        }

        fn parserFn(_: *const Parser(T), input: Input) MaybeParsed(T) {
            return .{ .err = input.err() };
        }
    };
}

pub fn ConstP(comptime T: type) type {
    return struct {
        thing: T,
        parser: Parser(T),

        pub fn init(thing: T) @This() {
            return .{ .thing = thing, .parser = .{ .parseFn = parserFn } };
        }

        fn parserFn(parser: *const Parser(T), input: Input) MaybeParsed(T) {
            const thing = @fieldParentPtr(@This(), "parser", parser).thing;
            return .{ .data = .{ .val = thing, .rest = input } };
        }
    };
}

pub const CharP = struct {
    char: u8,
    parser: Parser(u8),

    pub fn init(char: u8) @This() {
        return .{ .char = char, .parser = .{ .parseFn = parserFn } };
    }

    fn parserFn(parser: *const Parser(u8), input: Input) MaybeParsed(u8) {
        const char = @fieldParentPtr(@This(), "parser", parser).char;
        const str = input.str;
        if ( str.len == 0 or char != str[0] )
            return .{ .err = input.err() };
        return .{ .data = .{ .val = char, .rest = input.add(1) } };
    }
};

pub const PredP = struct {
    pred: fn(u8) bool,
    parser: Parser(u8),

    pub fn init(pred: fn(u8) bool) @This() {
        return .{ .pred = pred, .parser = .{ .parseFn = parserFn } };
    }

    fn parserFn(parser: *const Parser(u8), input: Input) MaybeParsed(u8) {
        const pred = @fieldParentPtr(@This(), "parser", parser).pred;
        const str = input.str;
        if ( str.len == 0 or !pred(str[0]) )
            return .{ .err = input.err() };
        return .{ .data = .{ .val = str[0], .rest = input.add(1) } };
    }
};

pub const SpanP = struct {
    pred: fn(u8) bool,
    parser: Parser([]const u8),

    pub fn init(pred: fn(u8) bool) @This() {
        return .{ .pred = pred, .parser = .{ .parseFn = parserFn } };
    }

    fn parserFn(parser: *const Parser([]const u8), input: Input) MaybeParsed([]const u8) {
        const pred = @fieldParentPtr(@This(), "parser", parser).pred;
        const str = input.str;
        var i: usize = 0;
        while ( i < str.len ) : ( i += 1 ) {
            if ( !pred(str[i]) )
                break;
        }
        return .{ .data = .{ .val = str[0..i], .rest = input.add(i) } };
    }
};

pub fn OptionP(comptime T: type) type {
    return struct {
        base: *const Parser(T),
        parser: Parser(?T),

        pub fn init(base: *const Parser(T)) @This() {
            return .{ .base = base, .parser = .{ .parseFn = parserFn } };
        }

        fn parserFn(parser: *const Parser(?T), input: Input) MaybeParsed(?T) {
            const self = @fieldParentPtr(@This(), "parser", parser);
            const base = self.base;
            switch ( base.parse(input) ) {
                .err => return .{ .data = .{ .val = null, .rest = input } },
                .data => |data| return .{ .data = .{ .val = data.val,
                        .rest = data.rest } },
            }
        }
    };
}

pub fn MappedP(comptime A: type, comptime B: type) type {
    return struct {
        func: fn(A) B,
        base: *const Parser(A),
        parser: Parser(B),

        pub fn init(func: fn(A) B, base: *const Parser(A)) @This() {
            return .{ .func = func, .base = base,
                .parser = .{ .parseFn = parserFn } };
        }

        fn parserFn(parser: *const Parser(B), input: Input) MaybeParsed(B) {
            const self = @fieldParentPtr(@This(), "parser", parser);
            const base = self.base; const func = self.func;
            return base.parse(input).map(B, func);
        }
    };
}

pub fn KeepP(comptime A: type, comptime B: type) type {
    return struct {
        fst: *const Parser(A),
        snd: *const Parser(B),
        parser: Parser(A),

        pub fn init(fst: *const Parser(A), snd: *const Parser(B)) @This() {
            return .{ .fst = fst, .snd = snd,
                .parser = .{ .parseFn = parseFn } };
        }

        fn parseFn(parser: *const Parser(A), input: Input) MaybeParsed(A) {
            const self = @fieldParentPtr(@This(), "parser", parser);
            const ret1 = self.fst.parse(input);
            switch ( ret1 ) {
                .err => return ret1,
                .data => |data| {
                    const ret2 = self.snd.parse(data.rest);
                    switch ( ret2 ) {
                        .err => return ret2.t(A),
                        .data => |data2| return .{ .data = .{
                                .val = data.val, .rest = data2.rest }},
                    }
                },
            }
        }
    };
}

pub fn SkipP(comptime A: type, comptime B: type) type {
    return struct {
        fst: *const Parser(A),
        snd: *const Parser(B),
        parser: Parser(B),

        pub fn init(fst: *const Parser(A), snd: *const Parser(B)) @This() {
            return .{ .fst = fst, .snd = snd,
                .parser = .{ .parseFn = parseFn } };
        }

        fn parseFn(parser: *const Parser(B), input: Input) MaybeParsed(B) {
            const self = @fieldParentPtr(@This(), "parser", parser);
            const ret1 = self.fst.parse(input);
            switch ( ret1 ) {
                .err => return ret1.t(B),
                .data => |data| {
                    const ret2 = self.snd.parse(data.rest);
                    switch ( ret2 ) {
                        .err => return ret2,
                        .data => |data2| return .{ .data = .{
                                .val = data2.val, .rest = data2.rest }},
                    }
                },
            }
        }
    };
}
