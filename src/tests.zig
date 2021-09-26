const parserLib = @import("parser.zig");
const Parser = parserLib.Parser;
const Parsed = parserLib.Parsed;
const Input = parserLib.Input;

const std = @import("std");
const testing = std.testing;
const expectEqual = testing.expectEqual;
const expectEqualStrings = testing.expectEqualStrings;

fn expectEqualInput(a: Input, b: Input) !void {
    try expectEqual(a.pos, b.pos);
    try expectEqualStrings(a.str, b.str);
}

fn expectEqualParsed(comptime T: type, a: Parsed(T), b: Parsed(T)) !void {
    try expectEqual(a.val, b.val);
    try expectEqualInput(a.rest, b.rest);
}

test "advancing input" {
    const input = Input.init("something");
    const expected = Input{ .pos = 4, .str = "thing"};
    try expectEqualInput(expected, input.add(4));
}

test "failing parser fail" {
    const input = Input.init("something");
    const failp = parserLib.FailP(u8).init();
    _ = failp.parser.parse(input).err;
}

test "const parser ok" {
    const input = Input.init("something");
    const expected = Parsed(bool){ .val = true,
        .rest = Input{ .str = "something" } };
    const constp = parserLib.ConstP(bool).init(true);
    const ret = constp.parser.parse(input).data;
    try expectEqualParsed(bool, expected, ret);
}

test "char parser ok" {
    const input = Input.init("something");
    const expected = Parsed(u8){ .val = 's',
        .rest = Input{ .pos = 1, .str = "omething" } };
    const charp = parserLib.CharP.init('s');
    const ret = charp.parser.parse(input).data;
    try expectEqualParsed(u8, expected, ret);
}

fn isLower(c: u8) bool { return 'a' <= c and c <= 'z'; }
test "pred parser ok" {
    const input = Input.init("something");
    const expected = Parsed(u8){ .val = 's',
        .rest = Input{ .pos = 1, .str = "omething" } };
    const predp = parserLib.PredP.init(isLower);
    const ret = predp.parser.parse(input).data;
    try expectEqualParsed(u8, expected, ret);
}

test "option parser ok" {
    const input = Input.init("something");
    const base = parserLib.CharP.init('s');
    const expected = Parsed(?u8){ .val = 's',
        .rest = Input{ .pos = 1, .str = "omething" } };
    const opt = parserLib.OptionP(u8).init(&base.parser);
    const ret = opt.parser.parse(input).data;
    try expectEqualParsed(?u8, expected, ret);
}

test "option parser null" {
    const input = Input.init("something");
    const base = parserLib.CharP.init('o');
    const expected = Parsed(?u8){ .val = null,
        .rest = Input{ .pos = 0, .str = "something" } };
    const opt = parserLib.OptionP(u8).init(&base.parser);
    const ret = opt.parser.parse(input).data;
    try expectEqualParsed(?u8, expected, ret);
}

fn truu(c: u8) bool { _ = c; return true; }
fn toDigit(d: u8) ?i8 { return if ('0' <= d and d <= '9') @intCast(i8, d) - '0' else null; }
test "mapped parser ok" {
    const input = Input.init("1something");
    const base = parserLib.PredP.init(truu);
    const expected = Parsed(?i8){ .val = 1,
        .rest = Input{ .pos = 1, .str = "something" } };
    const mapped = parserLib.MappedP(u8, ?i8).init(toDigit, &base.parser);
    const ret = mapped.parser.parse(input).data;
    try expectEqualParsed(?i8, expected, ret);
}

test "functor abstraction ok" {
    const input = Input.init("1something");
    const expected = Parsed(?i8){ .val = 1,
        .rest = Input{ .pos = 1, .str = "something" } };
    const base = parserLib.PredP.init(truu);
    const functor = base.parser.map(?i8, toDigit);
    const ret = functor.parser.parse(input).data;
    try expectEqualParsed(?i8, expected, ret);
}

test "keep parser ok" {
    const input = Input.init("something");
    const fst = parserLib.CharP.init('s');
    const snd = parserLib.CharP.init('o');
    const expected = Parsed(u8){ .val = 's',
        .rest = Input{ .pos = 2, .str = "mething" } };
    const keepp = parserLib.KeepP(u8, u8).init(&fst.parser, &snd.parser);
    const ret = keepp.parser.parse(input).data;
    try expectEqualParsed(u8, expected, ret);
}

test "keep abstraction ok" {
    const input = Input.init("something");
    const fst = parserLib.CharP.init('s');
    const snd = parserLib.CharP.init('o');
    const expected = Parsed(u8){ .val = 's',
        .rest = Input{ .pos = 2, .str = "mething" } };
    const keepp = fst.parser.keep(u8, &snd.parser);
    const ret = keepp.parser.parse(input).data;
    try expectEqualParsed(u8, expected, ret);
}

test "skip parser ok" {
    const input = Input.init("something");
    const fst = parserLib.CharP.init('s');
    const snd = parserLib.CharP.init('o');
    const expected = Parsed(u8){ .val = 'o',
        .rest = Input{ .pos = 2, .str = "mething" } };
    const skipp = parserLib.SkipP(u8, u8).init(&fst.parser, &snd.parser);
    const ret = skipp.parser.parse(input).data;
    try expectEqualParsed(u8, expected, ret);
}

test "skip abstraction ok" {
    const input = Input.init("something");
    const fst = parserLib.CharP.init('s');
    const snd = parserLib.CharP.init('o');
    const expected = Parsed(u8){ .val = 'o',
        .rest = Input{ .pos = 2, .str = "mething" } };
    const skipp = fst.parser.skip(u8, &snd.parser);
    const ret = skipp.parser.parse(input).data;
    try expectEqualParsed(u8, expected, ret);
}
