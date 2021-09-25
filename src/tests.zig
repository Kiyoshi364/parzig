const parserLib = @import("parser.zig");
const Parser = parserLib.Parser;
const ParserErr = parserLib.ParserErr;

const std = @import("std");
const testing = std.testing;
const alloc = testing.allocator;
const expect = testing.expect;
const expectEqual = testing.expectEqual;
const expectEqualStrings = testing.expectEqualStrings;
const expectError = testing.expectError;

test "builtin.is_test (this should always work)" {
    try expect(std.builtin.is_test);
}

test "failing parser fail" {
    const input = "something";
    const fail = parserLib.FailP(u8).init();
    const ret = fail.parser.parse(input);
    try expectError(ParserErr.ParserFailed, ret.data);
}

test "char parser ok" {
    const input = "something";
    const charP = parserLib.CharP.init('s');
    const ret = try charP.parser.parse(input).data;
    try expectEqual(@intCast(u8, 's'), ret.val);
    try expectEqualStrings("omething", ret.rest);
}

test "char parser fail" {
    const input = "something";
    const charP = parserLib.CharP.init('o');
    const ret = charP.parser.parse(input);
    try expectError(ParserErr.ParserFailed, ret.data);
}

test "sequence parser ok" {
    const CharP = parserLib.CharP;
    const input = "something";
    const charps = [_]CharP{ CharP.init('s'), CharP.init('o') };
    const parserArr = [_]*const Parser(u8){ &charps[0].parser, &charps[1].parser };

    const seqP = parserLib.SequenceP(u8, 2).init(parserArr);
    const ret = try seqP.parser.parse(input).data;

    try expectEqual([_]u8{'s', 'o'}, ret.val);
    try expectEqualStrings("mething", ret.rest);
}

test "sequence parser fail" {
    const CharP = parserLib.CharP;

    const input = "something";
    const charps = [_]CharP{ CharP.init('o'), CharP.init('m') };
    const parserArr = [_]*const Parser(u8){ &charps[0].parser, &charps[1].parser };

    const seqP = parserLib.SequenceP(u8, 2).init(parserArr);
    const ret = seqP.parser.parse(input).data;

    try expectError(ParserErr.ParserFailed, ret);
}

test "string parser ok" {
    const StringP = parserLib.StringP;

    const input = "something";
    const target = "somet";

    const strP = StringP(target.len).init(target);
    const ret = try strP.parser.parse(input).data;
    try expectEqualStrings(target, &ret.val);
    try expectEqualStrings("hing", ret.rest);
}

test "string parser fail" {
    const StringP = parserLib.StringP;

    const input = "something";
    const target = "omet";

    const strP = StringP(target.len).init(target);
    const ret = strP.parser.parse(input);
    try expectError(ParserErr.ParserFailed, ret.data);
}
