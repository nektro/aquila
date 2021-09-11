const std = @import("std");
const http = @import("apple_pie");
const files = @import("self/files");
const extras = @import("extras");

const mime = @import("../mime.zig");

const _internal = @import("./_internal.zig");
const _index = @import("./index.zig");
const _user = @import("./user.zig");
const _package = @import("./package.zig");

pub fn init(alloc: *std.mem.Allocator) !void {
    var secret_seed: [std.rand.DefaultCsprng.secret_seed_length]u8 = undefined;
    std.crypto.random.bytes(&secret_seed);
    var csprng = std.rand.DefaultCsprng.init(secret_seed);

    _internal.jwt_secret = try extras.randomSlice(alloc, &csprng.random, u8, 64);
}

pub fn getHandler() http.RequestHandler(void) {
    return http.router.Router(void, &.{
        http.router.get("/", _index.get),
        file_route("/theme.css"),
        http.router.get("/about", StaticPek("/about.pek").get),
        http.router.get("/contact", StaticPek("/contact.pek").get),
        http.router.get("/:remote/:user", Middleware(_user.get).next),
        http.router.get("/:remote/:user/:package", Middleware(_package.get).next),
    });
}

fn Middleware(comptime f: anytype) type {
    const Args = @typeInfo(@TypeOf(f)).Fn.args[3].arg_type.?;
    return struct {
        pub fn next(_: void, response: *http.Response, request: http.Request, args: Args) !void {
            f({}, response, request, args) catch |err| {
                if (@as(anyerror, err) == error.HttpNoOp) return;
                return err;
            };
        }
    };
}

fn file_route(comptime path: []const u8) http.router.Route {
    const T = struct {
        fn f(_: void, response: *http.Response, request: http.Request) !void {
            _ = request;

            if (comptime mime.typeByExtension(std.fs.path.extension(path))) |mediatype| {
                try response.headers.put("Content-Type", mediatype);
            }
            const w = response.writer();
            try w.writeAll(files.open(path).?);
        }
    };
    return http.router.get(path, T.f);
}

fn StaticPek(comptime path: []const u8) type {
    return struct {
        pub fn get(_: void, response: *http.Response, request: http.Request) !void {
            try _internal.writePageResponse(request.arena, response, request, path, .{
                .aquila_version = @import("root").version,
                .logged_in = false,
            });
        }
    };
}
