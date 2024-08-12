const std = @import("std");
const Browser = @import("browser.zig").Browser;
const FileMonitor = @import("file-monitor.zig").FileMonitor;

pub fn main() !void {
    var args = std.process.args();
    const exe_name = args.next() orelse "zframe";
    const observe_dir = args.next() orelse {
        std.log.err("Usage: {s} <observe_dir>", .{exe_name});
        return;
    };

    var browser = Browser.init(.chrome);
    try browser.openHtml();
    var Monitor = try FileMonitor.init(observe_dir);
    defer Monitor.deinit();
    while(true) {
        if (Monitor.detectChanges()) {
            try autobuild();
            try browser.reload();
        }
        std.time.sleep(1000000000);
    }
}

fn autobuild() !void {
    var arena_allocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const build_command = &.{"zig", "build", "run"};
    const fork_pid = try std.posix.fork();
    if (fork_pid == 0) {
        // child process
        const err = std.process.execve(arena_allocator.allocator(), build_command, null); // noreturn if success
        std.debug.print("{s}\n", .{@errorName(err)});
    } else {
        // parent process
        const wait_result = std.posix.waitpid(fork_pid, 0);
        if (wait_result.status != 0) {
            std.debug.print("exit code: {}\n", .{wait_result.status});
        }
    }
}
