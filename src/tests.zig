const parserLib = @import("parser.zig");
const Parser = parserLib.Parser;
const ParserErr = parserLib.ParserErr;

const std = @import("std");
const testing = std.testing;
const expectEqual = testing.expectEqual;
const expectEqualStrings = testing.expectEqualStrings;
const expectError = testing.expectError;

test "failing parser fail" {
    const input = "something";
    const failp = parserLib.FailP(u8).init();
    const ret = failp.parser.parse(input);
    try expectError(ParserErr.ParserFailed, ret.data);
}

test "const parser ok" {
    const input = "something";
    const constp = parserLib.ConstP(bool).init(true);
    const ret = try constp.parser.parse(input).data;
    try expectEqual(true, ret.val);
    try expectEqualStrings(input, ret.rest);
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

    const seqP = parserLib.SequenceP(u8, 2).init(&parserArr);
    const ret = try seqP.parser.parse(input).data;

    try expectEqual([_]u8{'s', 'o'}, ret.val);
    try expectEqualStrings("mething", ret.rest);
}

test "sequence parser fail" {
    const CharP = parserLib.CharP;

    const input = "something";
    const charps = [_]CharP{ CharP.init('o'), CharP.init('m') };
    const parserArr = [_]*const Parser(u8){ &charps[0].parser, &charps[1].parser };

    const seqP = parserLib.SequenceP(u8, 2).init(&parserArr);
    const ret = seqP.parser.parse(input).data;

    try expectError(ParserErr.ParserFailed, ret);
}

test "string parser ok" {
    const input = "something";
    const target = "somet";

    const strP = parserLib.StringP.init(target);
    const ret = try strP.parser.parse(input).data;
    try expectEqualStrings(target, ret.val);
    try expectEqualStrings("hing", ret.rest);
}

test "string parser fail" {
    const input = "something";
    const target = "omet";

    const strP = parserLib.StringP.init(target);
    const ret = strP.parser.parse(input);
    try expectError(ParserErr.ParserFailed, ret.data);
}

test "scanp parser ok" {
    const input = "aAabaAa";
    const func = isA;

    const scanp = parserLib.ScanP.init(func);
    const ret = try scanp.parser.parse(input).data;
    try expectEqualStrings("aAa", ret.val);
    try expectEqualStrings("baAa", ret.rest);
}
fn isA(c: u8) bool { return c == 'a' or c == 'A'; }

test "scanp parser everything" {
    const input = "everything";
    const func = isLowerAlph;

    const scanp = parserLib.ScanP.init(func);
    const ret = try scanp.parser.parse(input).data;
    try expectEqualStrings(input, ret.val);
    try expectEqualStrings("", ret.rest);
}
fn isLowerAlph(c: u8) bool { return 'a' <= c and c <= 'z'; }

test "mapped parser ok" {
    const CharP = parserLib.CharP;

    const input = "something";
    const func = sub11;
    const base = &CharP.init('s').parser;

    const mappedp = parserLib.MappedP(u8, i8).init(func, base);
    const ret = try mappedp.parser.parse(input).data;
    try expectEqual(@intCast(i8, 'h'), ret.val);
    try expectEqualStrings("omething", ret.rest);
}
fn sub11(x: u8) i8 { return @intCast(i8, x) - 11; }

test "mapped parser fail" {
    const CharP = parserLib.CharP;

    const input = "omething";
    const func = sub11;
    const base = &CharP.init('s').parser;

    const mappedp = parserLib.MappedP(u8, i8).init(func, base);
    const ret = mappedp.parser.parse(input).data;
    try expectError(ParserErr.ParserFailed, ret);
}

test "Parser(T) is a functor!" {
    const CharP = parserLib.CharP;

    const input = "something";
    const func = sub11;
    const base = &CharP.init('s').parser;

    const mappedp = base.fmap(i8, func);
    const ret = try mappedp.parser.parse(input).data;
    try expectEqual(@intCast(i8, 'h'), ret.val);
    try expectEqualStrings("omething", ret.rest);
}

test "applied parser ok" {
    const ConstP = parserLib.ConstP;
    const CharP = parserLib.CharP;

    const input = "something";
    const funcp = &ConstP(fn(u8) i8).init(sub11).parser;
    const base = &CharP.init('s').parser;

    const appliedp = parserLib.AppliedP(u8, i8).init(funcp, base);
    const ret = try appliedp.parser.parse(input).data;
    try expectEqual(@intCast(i8, 'h'), ret.val);
    try expectEqualStrings("omething", ret.rest);
}

test "applied parser fail" {
    const FailP = parserLib.FailP;
    const CharP = parserLib.CharP;

    const input = "something";
    const funcp = &FailP(fn(u8) i8).init().parser;
    const base = &CharP.init('s').parser;

    const appliedp = parserLib.AppliedP(u8, i8).init(funcp, base);
    const ret = appliedp.parser.parse(input).data;
    try expectError(ParserErr.ParserFailed, ret);
}

//test "applied parser2(0) ok" {
//    const ConstP = parserLib.ConstP;
//    const CharP = parserLib.CharP;
//
//    const input = "something";
//    const funcp = &ConstP(fn(u8) i8).init(sub11).parser;
//    const base = &CharP.init('s').parser;
//
//    @import("std").debug.print("\n", .{});
//
//    const appliedp = parserLib.AppliedP2(u8, i8, 0).init(funcp, base);
//    const ret = try appliedp.parser.parse(input).data;
//    try expectEqual(@intCast(i8, 'h'), ret.val);
//    try expectEqualStrings("omething", ret.rest);
//}
//
//test "applied parser2(1) ok" {
//    const ConstP = parserLib.ConstP;
//    const CharP = parserLib.CharP;
//
//    const input = "something";
//    const funcp = &ConstP(fn(u8) i8).init(sub11).parser;
//    const base = &CharP.init('s').parser;
//
//    const appliedp = parserLib.AppliedP2(u8, i8, 1).init(funcp, base);
//    const ret = try appliedp.parser.parse(input).data;
//    try expectEqual(@intCast(i8, 'h'), ret.val);
//    try expectEqualStrings("omething", ret.rest);
//}
