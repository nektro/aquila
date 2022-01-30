const std = @import("std");
const string = []const u8;
const zorm = @import("zorm");
const ulid = @import("ulid");
const extras = @import("extras");

pub const Engine = zorm.engine(.sqlite3);
pub var db: Engine = undefined;

const epoch: i64 = 1577836800000; // 'Jan 1 2020' -> unix milli
pub var factory = ulid.Factory.init(epoch, std.crypto.random);

pub const Order = enum {
    asc,
    desc,
};

pub fn TableTypeMixin(comptime T: type) type {
    return struct {
        pub fn size(alloc: std.mem.Allocator) !u64 {
            const n = try db.first(alloc, u64, "select id from " ++ T.table_name ++ " order by id desc limit 1", .{});
            return n orelse 0;
        }

        pub fn all(alloc: std.mem.Allocator, comptime ord: Order) ![]const T {
            return try db.collect(alloc, T, "select * from " ++ T.table_name ++ " order by id " ++ @tagName(ord), .{});
        }
    };
}

pub fn ByKeyGen(comptime T: type) type {
    return struct {
        pub fn byKey(alloc: std.mem.Allocator, comptime key: std.meta.FieldEnum(T), value: extras.FieldType(T, key)) !?T {
            return try db.first(
                alloc,
                T,
                "select * from " ++ T.table_name ++ " where " ++ @tagName(key) ++ " = ?",
                foo(@tagName(key), value),
            );
        }

        pub fn byKeyAll(alloc: std.mem.Allocator, comptime key: std.meta.FieldEnum(T), value: extras.FieldType(T, key)) ![]const T {
            return try db.collect(
                alloc,
                T,
                "select * from " ++ T.table_name ++ " where " ++ @tagName(key) ++ " = ?",
                foo(@tagName(key), value),
            );
        }

        fn updateColumn(self: T, alloc: std.mem.Allocator, comptime key: std.meta.FieldEnum(T), value: extras.FieldType(T, key)) !void {
            return try db.exec(
                alloc,
                "update " ++ T.table_name ++ " set " ++ @tagName(key) ++ " = ? where id = ?",
                merge(.{
                    foo(@tagName(key), value),
                    foo("id", self.id),
                }),
            );
        }

        pub fn update(self: *T, alloc: std.mem.Allocator, comptime key: std.meta.FieldEnum(T), value: extras.FieldType(T, key)) !void {
            try updateColumn(self.*, alloc, key, value);
            @field(self, @tagName(key)) = value;
        }
    };
}

pub fn FindByGen(comptime S: type, comptime H: type, searchCol: std.meta.FieldEnum(H), selfCol: std.meta.FieldEnum(S)) type {
    const querystub = "select * from " ++ H.table_name ++ " where " ++ @tagName(searchCol) ++ " = ?";
    return struct {
        pub fn first(self: S, alloc: std.mem.Allocator, comptime key: std.meta.FieldEnum(H), value: extras.FieldType(H, key)) !?H {
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

pub fn insert(alloc: std.mem.Allocator, value: anytype) !std.meta.Child(@TypeOf(value)) {
    const T = std.meta.Child(@TypeOf(value));
    @field(value, "id") = try nextId(alloc, T);
    comptime var parens: string = "";
    inline for (std.meta.fields(T)) |_, i| {
        if (i != 0) parens = parens ++ ", ";
        parens = parens ++ "?";
    }
    try db.exec(alloc, "insert into " ++ T.table_name ++ " values (" ++ parens ++ ")", value.*);
    return value.*;
}

fn nextId(alloc: std.mem.Allocator, comptime T: type) !u64 {
    return (try T.size(alloc)) + 1;
}

pub fn createTableT(alloc: std.mem.Allocator, eng: *Engine, comptime T: type) !void {
    const tI = @typeInfo(T).Struct;
    const fields = tI.fields;
    try createTable(alloc, eng, T.table_name, comptime colToCol(fields[0]), comptime fieldsToCols(fields[1..]));
}

fn createTable(alloc: std.mem.Allocator, eng: *Engine, comptime name: string, comptime pk: [2]string, comptime cols: []const [2]string) !void {
    if (try eng.doesTableExist(alloc, name)) {} else {
        std.log.scoped(.db).info("creating table '{s}' with primary column '{s}'", .{ name, pk[0] });
        try eng.exec(alloc, comptime std.fmt.comptimePrint("create table {s}({s} {s})", .{ name, pk[0], pk[1] }), .{});
    }
    inline for (cols) |item| {
        if (try eng.hasColumnWithName(alloc, name, item[0])) {} else {
            std.log.scoped(.db).info("adding column to '{s}': '{s}'", .{ name, item[0] });
            try eng.exec(alloc, comptime std.fmt.comptimePrint("alter table {s} add {s} {s}", .{ name, item[0], item[1] }), .{});
        }
    }
}

fn fieldsToCols(comptime fields: []const std.builtin.TypeInfo.StructField) []const [2]string {
    comptime {
        var result: [fields.len][2]string = undefined;
        for (fields) |item, i| {
            result[i] = colToCol(item);
        }
        return &result;
    }
}

fn colToCol(comptime field: std.builtin.TypeInfo.StructField) [2]string {
    return [_]string{
        field.name,
        typeToSqliteType(field.field_type),
    };
}

fn typeToSqliteType(comptime T: type) string {
    if (comptime std.meta.trait.isZigString(T)) {
        return "text";
    }
    switch (@typeInfo(T)) {
        .Struct, .Enum, .Union => if (@hasDecl(T, "BaseType")) return typeToSqliteType(T.BaseType),
        else => {},
    }
    return switch (T) {
        u32, u64 => "int",
        else => @compileError("typeToSqliteType: " ++ @typeName(T)),
    };
}
