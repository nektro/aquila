const http = @import("apple_pie");

const db = @import("./../db/_db.zig");

const _internal = @import("./_internal.zig");

pub fn get(_: void, response: *http.Response, request: http.Request, args: struct {}) !void {
    _ = args;
    const alloc = request.arena;

    try _internal.writePageResponse(alloc, response, request, "/stats.pek", .{
        .aquila_version = @import("root").version,
        .page = "index",
        .title = "Statistics",
        .user = try _internal.getUserOp(response, request),
        .chart1 = try db.chart1(alloc),
        .chart2 = try db.chart2(alloc),
        .chart3 = try db.chart3(alloc),
        .chart4 = try db.chart4(alloc),
        .chart5 = try db.chart5(alloc),
        .chart6 = try db.chart6(alloc),
    });
}
