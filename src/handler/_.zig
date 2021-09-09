const std = @import("std");
const http = @import("apple_pie");
const files = @import("self/files");

const mime = @import("../mime.zig");

const _internal = @import("./_internal.zig");
const _index = @import("./index.zig");
const _user = @import("./user.zig");
const _package = @import("./package.zig");

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
            f({}, response, request, args) catch |err| switch (err) {
                error.HttpNoOp => {},
                else => return err,
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
