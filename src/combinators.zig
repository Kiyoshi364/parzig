const std = @import("std");
const assert = std.debug.assert;

const parzig = @import("parzig.zig");
const Parser = parzig.Parser;
const MaybeParsed = parzig.MaybeParsed;
const Parsed = parzig.Parsed;
const Input = parzig.Input;

const blocks = @import("blocks.zig");
const MappedP = blocks.MappedP;

const testing = std.testing;
const expectEqual = testing.expectEqual;
const expectEqualParsed = @import("tests.zig").expectEqualParsed;

fn ParserT(comptime p: anytype) type {
    const P = switch ( @typeInfo(@TypeOf(p)) ) {
        .Pointer => |ptr| blk: { assert(ptr.is_const); break :blk ptr.child; },
        .Struct => @TypeOf(p),
        else =>
            @compileError("Expected a Parser or a Parser implementation, found "
                ++ @typeName(p)),
    };
    if ( @hasField(P, "parser") ) {
        return ParserT(@field(p, "parser"));
    } else if ( @hasField(P, "parseFn") ) {
        const fnInfo = switch ( @typeInfo(@TypeOf(@field(p, "parseFn"))) ) {
            .Fn, .BoundFn => |a| a,
            else => @compileError("Expected a Parser implementation"),
        };
        const args = fnInfo.args;
        assert(args.len == 2);
        assert(args[1].arg_type.? == Input);

        const arg0Info = @typeInfo(args[0].arg_type.?).Pointer;
        assert(arg0Info.is_const);
        assert(@hasField(arg0Info.child, "parseFn"));

        const PType = @field(arg0Info.child, "Val");
        assert(Parser(PType) == P);

        const Ret = fnInfo.return_type.?;
        const RetType = @field(Ret, "Val");
        assert(PType == RetType);
        assert(MaybeParsed(RetType) == Ret);

        return PType;
    } else {
        @compileError("Expected a Parser implementation, found '" ++
            @typeName(P) ++ "'");
    }
}

test "ParserT interface 1" {
    const T = void;
    const parser = comptime blocks.FailP(T).init().parser;
    try expectEqual(T, ParserT(parser));
}

test "ParserT interface 2" {
    const parser = comptime blocks.CharP.init('p').parser;
    try expectEqual(u8, ParserT(parser));
}

test "ParserT implementation 1" {
    const T = void;
    const parser = comptime blocks.FailP(T).init();
    try expectEqual(T, ParserT(parser));
}

test "ParserT implementation 2" {
    const parser = comptime blocks.CharP.init('p');
    try expectEqual(u8, ParserT(parser));
}

pub fn MappedT(comptime f: anytype, comptime p: anytype) type {
    const fnInfo = switch ( @typeInfo(@TypeOf(f)) ) {
        .Fn, .BoundFn => |a| a,
        else => @compileError("Expected a function, found " ++ @typeName(f)),
    };
    const PType = ParserT(p);

    const args = fnInfo.args;
    assert(args.len == 1);
    assert(args[0].arg_type.? == PType);

    const Ret = fnInfo.return_type.?;

    return MappedP(PType, Ret);
}

fn dummyFn(_: void) u3 { return 0; }
test "MappedT interface 1" {
    const parser = comptime blocks.FailP(void).init().parser;
    try expectEqual(MappedP(void, u3), MappedT(dummyFn, parser));
}

fn dummyFn2(c: u8) u3 { return @intCast(u3, c&0x7); }
test "MappedT interface 2" {
    const parser = comptime blocks.CharP.init('p').parser;
    try expectEqual(MappedP(u8, u3), MappedT(dummyFn2, parser));
}

test "MappedT implementation 1" {
    const parser = comptime blocks.FailP(void).init();
    try expectEqual(MappedP(void, u3), MappedT(dummyFn, parser));
}

test "MappedT implementation 2" {
    const parser = comptime blocks.CharP.init('p');
    try expectEqual(MappedP(u8, u3), MappedT(dummyFn2, parser));
}

pub fn map(comptime f: anytype, comptime p: anytype) MappedT(f, p) {
    return MappedT(f, p).init(f, &p.parser);
}

test "map implementation" {
    const input = Input.init("something");
    const base = comptime blocks.CharP.init('s');
    const expected = Parsed(u3){ .val = 3,
        .rest = Input{ .pos = 1, .str = "omething" } };
    const ret = map(dummyFn2, base).parser.parse(input).data;
    try expectEqualParsed(u3, expected, ret);
}
