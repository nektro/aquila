const std = @import("std");
const string = []const u8;
const zorm = @import("zorm");

pub const Engine = zorm.engine(.sqlite3);
pub var db: Engine = undefined;

pub fn ByKeyGen(comptime T: type, comptime table_name: string) type {
    return struct {
        pub fn byKey(alloc: *std.mem.Allocator, comptime key: std.meta.FieldEnum(T), value: FieldType(T, @tagName(key))) !?T {
            return try db.first(
                alloc,
                T,
                "select * from " ++ table_name ++ " where " ++ @tagName(key) ++ " = ?",
                foo(@tagName(key), value),
            );
        }
    };
}

fn FieldType(comptime T: type, comptime name: string) type {
    inline for (std.meta.fields(T)) |item| {
        if (std.mem.eql(u8, item.name, name)) {
            return item.field_type;
        }
    }
    @compileError(@typeName(T) ++ " does not have a field named " ++ name);
}

pub fn foo(comptime name: string, value: anytype) Struct(name, @TypeOf(value)) {
    const T = @TypeOf(value);
    var x: Struct(name, T) = undefined;
    @field(x, name) = value;
    return x;
}

pub fn Struct(comptime name: string, comptime T: type) type {
    return @Type(.{ .Struct = .{ .layout = .Auto, .fields = &.{structField(name, T)}, .decls = &.{}, .is_tuple = false } });
}

pub fn structField(comptime name: string, comptime T: type) std.builtin.TypeInfo.StructField {
    return .{ .name = name, .field_type = T, .default_value = null, .is_comptime = false, .alignment = @alignOf(T) };
}
