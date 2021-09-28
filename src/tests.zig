const parzig = @import("parzig.zig");
const Parser = parzig.Parser;
const Parsed = parzig.Parsed;
const Input = parzig.Input;
const blocks = parzig.blocks;

const std = @import("std");
const testing = std.testing;
const expectEqual = testing.expectEqual;
const expectEqualStrings = testing.expectEqualStrings;

fn expectEqualInput(a: Input, b: Input) !void {
    try expectEqual(a.pos, b.pos);
    try expectEqualStrings(a.str, b.str);
}

pub fn expectEqualParsed(comptime T: type, a: Parsed(T), b: Parsed(T)) !void {
    try if ( T == []const u8 ) expectEqualStrings(a.val, b.val)
        else expectEqual(a.val, b.val);
    try expectEqualInput(a.rest, b.rest);
}

test "advancing input" {
    const input = Input.init("something");
    const expected = Input{ .pos = 4, .str = "thing"};
    try expectEqualInput(expected, input.add(4));
}

test "ok parser ok" {
    const input = "something";
    const okp = blocks.OkP.init();
    const expected = Parsed(void){ .val = .{},
        .rest = Input{ .str = "something" } };
    const ret = okp.parser.parse(input).data;
    try expectEqualParsed(void, expected, ret);
}

test "failing parser fail" {
    const input = "something";
    const failp = blocks.FailP(u8).init();
    _ = failp.parser.parse(input).err;
}

test "const parser ok" {
    const input = "something";
    const expected = Parsed(bool){ .val = true,
        .rest = Input{ .str = "something" } };
    const constp = blocks.ConstP(bool).init(true);
    const ret = constp.parser.parse(input).data;
    try expectEqualParsed(bool, expected, ret);
}

test "char parser ok" {
    const input = "something";
    const expected = Parsed(u8){ .val = 's',
        .rest = Input{ .pos = 1, .str = "omething" } };
    const charp = blocks.CharP.init('s');
    const ret = charp.parser.parse(input).data;
    try expectEqualParsed(u8, expected, ret);
}

fn isLower(c: u8) bool { return 'a' <= c and c <= 'z'; }
test "pred parser ok" {
    const input = "something";
    const expected = Parsed(u8){ .val = 's',
        .rest = Input{ .pos = 1, .str = "omething" } };
    const predp = blocks.PredP.init(isLower);
    const ret = predp.parser.parse(input).data;
    try expectEqualParsed(u8, expected, ret);
}

test "span parser ok" {
    const input = "someThing";
    const expected = Parsed([]const u8){ .val = "some",
        .rest = Input{ .pos = 4, .str = "Thing" } };
    const spanp = blocks.SpanP.init(isLower);
    const ret = spanp.parser.parse(input).data;
    try expectEqualParsed([]const u8, expected, ret);
}

test "span parser everything" {
    const input = "everything";
    const expected = Parsed([]const u8){ .val = "everything",
        .rest = Input{ .pos = 10, .str = "" } };
    const spanp = blocks.SpanP.init(isLower);
    const ret = spanp.parser.parse(input).data;
    try expectEqualParsed([]const u8, expected, ret);
}

test "option parser ok" {
    const input = "something";
    const base = blocks.CharP.init('s');
    const expected = Parsed(?u8){ .val = 's',
        .rest = Input{ .pos = 1, .str = "omething" } };
    const opt = blocks.OptionP(u8).init(&base.parser);
    const ret = opt.parser.parse(input).data;
    try expectEqualParsed(?u8, expected, ret);
}

test "option parser null" {
    const input = "something";
    const base = blocks.CharP.init('o');
    const expected = Parsed(?u8){ .val = null,
        .rest = Input{ .pos = 0, .str = "something" } };
    const opt = blocks.OptionP(u8).init(&base.parser);
    const ret = opt.parser.parse(input).data;
    try expectEqualParsed(?u8, expected, ret);
}

fn truu(_: u8) bool { return true; }
fn toDigit(d: u8) ?i8 { return if ('0' <= d and d <= '9') @intCast(i8, d) - '0' else null; }
test "mapped parser ok" {
    const input = "1something";
    const base = blocks.PredP.init(truu);
    const expected = Parsed(?i8){ .val = 1,
        .rest = Input{ .pos = 1, .str = "something" } };
    const mapped = blocks.MappedP(u8, ?i8).init(toDigit, &base.parser);
    const ret = mapped.parser.parse(input).data;
    try expectEqualParsed(?i8, expected, ret);
}

test "functor abstraction ok" {
    const input = "1something";
    const expected = Parsed(?i8){ .val = 1,
        .rest = Input{ .pos = 1, .str = "something" } };
    const base = comptime blocks.PredP.init(truu);
    const functor = comptime base.parser.map(toDigit);
    const ret = functor.parser.parse(input).data;
    try expectEqualParsed(?i8, expected, ret);
}

test "keep parser ok" {
    const input = "something";
    const fst = blocks.CharP.init('s');
    const snd = blocks.CharP.init('o');
    const expected = Parsed(u8){ .val = 's',
        .rest = Input{ .pos = 2, .str = "mething" } };
    const keepp = blocks.KeepP(u8, u8).init(&fst.parser, &snd.parser);
    const ret = keepp.parser.parse(input).data;
    try expectEqualParsed(u8, expected, ret);
}

test "keep abstraction ok" {
    const input = "something";
    const fst = blocks.CharP.init('s');
    const snd = blocks.CharP.init('o');
    const expected = Parsed(u8){ .val = 's',
        .rest = Input{ .pos = 2, .str = "mething" } };
    const keepp = fst.parser.keep(u8, &snd.parser);
    const ret = keepp.parser.parse(input).data;
    try expectEqualParsed(u8, expected, ret);
}

test "skip parser ok" {
    const input = "something";
    const fst = blocks.CharP.init('s');
    const snd = blocks.CharP.init('o');
    const expected = Parsed(u8){ .val = 'o',
        .rest = Input{ .pos = 2, .str = "mething" } };
    const skipp = blocks.SkipP(u8, u8).init(&fst.parser, &snd.parser);
    const ret = skipp.parser.parse(input).data;
    try expectEqualParsed(u8, expected, ret);
}

test "skip abstraction ok" {
    const input = "something";
    const fst = blocks.CharP.init('s');
    const snd = blocks.CharP.init('o');
    const expected = Parsed(u8){ .val = 'o',
        .rest = Input{ .pos = 2, .str = "mething" } };
    const skipp = fst.parser.skip(u8, &snd.parser);
    const ret = skipp.parser.parse(input).data;
    try expectEqualParsed(u8, expected, ret);
}
