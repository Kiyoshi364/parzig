pub const blocks = @import("blocks.zig");
pub const combinators = @import("combinators.zig");

pub fn ParseFunc(comptime T: type) type {
    return fn(*const Parser(T), Input) MaybeParsed(T);
}

pub fn Parser(comptime V: type) type {
    return struct {
        const Self = @This();
        pub const Val = V;
        const MappedT = combinators.MappedT;
        const KeepP = blocks.KeepP;
        const SkipP = blocks.SkipP;

        parseFn: ParseFunc(Val),

        pub fn parse(self: *const Self, input: Input) MaybeParsed(Val) {
            return self.parseFn(self, input);
        }

        pub fn map(self: *const Self, func: anytype) MappedT(func, self) {
            return MappedT(func, self).init(func, self);
        }

        pub fn keep(self: *const Self, comptime T: type, snd: *const Parser(T)) KeepP(Val, T) {
            return KeepP(Val, T).init(self, snd);
        }

        pub fn skip(self: *const Self, comptime T: type, snd: *const Parser(T)) SkipP(Val, T) {
            return SkipP(Val, T).init(self, snd);
        }
    };
}

pub const Input = struct {
    const Self = @This();

    pos: usize = 0,
    str: []const u8,

    pub fn init(str: []const u8) Self {
        return .{ .str = str };
    }

    pub fn add(self: Self, count: usize) Self {
        @import("std").debug.assert(count <= self.str.len);
        return .{ .pos = self.pos + count, .str = self.str[count..] };
    }

    pub fn err(self: Self) Error {
        return .{ .pos = self.pos };
    }
};

pub const Error = struct {
    pos: usize = 0,
};

pub fn MaybeParsed(comptime V: type) type {
    return union(enum) {
        const Self = @This();
        pub const Val = V;

        err: Error,
        data: Parsed(Val),

        pub fn map(self: Self, comptime T: type, func: fn(Val) T) MaybeParsed(T) {
            switch (self) {
                .err => |err| return .{ .err = err },
                .data => |data| return .{ .data =
                    .{ .val = func(data.val), .rest = data.rest } },
            }
        }

        pub fn t(self: Self, comptime T: type) MaybeParsed(T) {
            switch (self) {
                .err => |err| return .{ .err = err },
                .data => unreachable,
            }
        }
    };
}

pub fn Parsed(comptime Val: type) type {
    return struct {
        pub const Val = Val;
        val: Val,
        rest: Input,
    };
}
