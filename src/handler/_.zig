const std = @import("std");
const http = @import("apple_pie");
const files = @import("self/files");

const mime = @import("../mime.zig");
const __ = @import("./_internal.zig");
const _index = @import("./index.zig");

pub fn getHandler() http.RequestHandler(void) {
    return http.router.Router(void, &.{
        http.router.get("/", _index.get),
        file_route("/theme.css"),
    });
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