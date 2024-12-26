const std = @import("std");
const vaxis = @import("vaxis");
const Cell = vaxis.Cell;

const Event = union(enum) {
    key_press: vaxis.Key,
    winsize: vaxis.Winsize,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) {
            std.log.err("memory leak", .{});
        }
    }
    const alloc = gpa.allocator();

    var tty = try vaxis.Tty.init();
    defer tty.deinit();

    var buffered_writer = tty.bufferedWriter();
    const writer = buffered_writer.writer().any();

    var vx = try vaxis.init(alloc, .{});
    defer vx.deinit(alloc, tty.anyWriter());

    var loop: vaxis.Loop(Event) = .{ .tty = &tty, .vaxis = &vx };
    try loop.init();

    try loop.start();
    defer loop.stop();

    try vx.enterAltScreen(tty.anyWriter());
    try vx.queryTerminal(tty.anyWriter(), 1 * std.time.ns_per_s);

    while (true) {
        const event = loop.nextEvent();

        switch (event) {
            .key_press => |key| {
                if (key.matches('c', .{ .ctrl = true })) {
                    break;
                } else if (key.matches('l', .{ .ctrl = true })) {
                    vx.queueRefresh();
                }
            },
            .winsize => |ws| try vx.resize(alloc, tty.anyWriter(), ws),
        }

        const win = vx.window();
        win.clear();

        // Draw "Gentrace" at the top left
        const segments = [_]vaxis.Segment{.{
            .text = "Gentrace",
            .style = .{ .fg = .{ .index = 7 } }, // Use bright white (index 7)
        }};
        _ = win.print(&segments, .{});

        try vx.render(writer);
        try buffered_writer.flush();
    }
}
