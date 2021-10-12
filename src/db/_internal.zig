const std = @import("std");
const string = []const u8;
const zorm = @import("zorm");
const ulid = @import("ulid");

pub const Engine = zorm.engine(.sqlite3);
pub var db: Engine = undefined;

const epoch: i64 = 1577836800000; // 'Jan 1 2020' -> unix milli
pub var factory = ulid.Factory.init(epoch, std.crypto.random);

pub fn ByKeyGen(comptime T: type) type {
    return struct {
        pub fn byKey(alloc: *std.mem.Allocator, comptime key: std.meta.FieldEnum(T), value: FieldType(T, @tagName(key))) !?T {
            return try db.first(
                alloc,
                T,
                "select * from " ++ T.table_name ++ " where " ++ @tagName(key) ++ " = ?",
                foo(@tagName(key), value),
            );
        }

        pub fn byKeyAll(alloc: *std.mem.Allocator, comptime key: std.meta.FieldEnum(T), value: FieldType(T, @tagName(key))) ![]const T {
            return try db.collect(
                alloc,
                T,
                "select * from " ++ T.table_name ++ " where " ++ @tagName(key) ++ " = ?",
                foo(@tagName(key), value),
            );
        }
    };
}

pub fn FindByGen(comptime S: type, comptime H: type, searchCol: std.meta.FieldEnum(H), selfCol: std.meta.FieldEnum(S)) type {
    const querystub = "select * from " ++ H.table_name ++ " where " ++ @tagName(searchCol) ++ " = ?";
    return struct {
        pub fn first(self: S, alloc: *std.mem.Allocator, comptime key: std.meta.FieldEnum(H), value: FieldType(H, @tagName(key))) !?H {
            const query = querystub ++ " and " ++ @tagName(key) ++ " = ?";
            return try db.first(
                alloc,
                H,
                query,
                merge(.{
                    foo(@tagName(searchCol), @field(self, @tagName(selfCol))),
                    foo(@tagName(key), value),
                }),
            );
        }
    };
}

pub fn FieldType(comptime T: type, comptime name: string) type {
    inline for (std.meta.fields(T)) |item| {
        if (std.mem.eql(u8, item.name, name)) {
            return item.field_type;
        }
    }
    @compileError(@typeName(T) ++ " does not have a field named " ++ name);
}

fn foo(comptime name: string, value: anytype) Foo(name, @TypeOf(value)) {
    const T = @TypeOf(value);
    var x: Foo(name, T) = undefined;
    @field(x, name) = value;
    return x;
}

fn Foo(comptime name: string, comptime T: type) type {
    return Struct(&[_]std.builtin.TypeInfo.StructField{structField(name, T)});
}

fn Struct(comptime fields: []const std.builtin.TypeInfo.StructField) type {
    return @Type(.{ .Struct = .{ .layout = .Auto, .fields = fields, .decls = &.{}, .is_tuple = false } });
}

fn structField(comptime name: string, comptime T: type) std.builtin.TypeInfo.StructField {
    return .{ .name = name, .field_type = T, .default_value = null, .is_comptime = false, .alignment = @alignOf(T) };
}

fn merge(input: anytype) Merge(@TypeOf(input)) {
    const T = @TypeOf(input);
    var x: Merge(T) = undefined;
    inline for (std.meta.fields(T)) |item| {
        const a = @field(input, item.name);
        const b = std.meta.fields(item.field_type)[0].name;
        @field(x, b) = @field(a, b);
    }
    return x;
}

fn Merge(comptime T: type) type {
    var fields: []const std.builtin.TypeInfo.StructField = &.{};
    inline for (std.meta.fields(T)) |item| {
        const f = std.meta.fields(item.field_type)[0];
        fields = fields ++ &[_]std.builtin.TypeInfo.StructField{structField(f.name, f.field_type)};
    }
    return Struct(fields);
}
