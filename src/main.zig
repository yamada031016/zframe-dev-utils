const std = @import("std");
const Browser = @import("browser.zig").Browser;
const FileMonitor = @import("file-monitor.zig").FileMonitor;
const HTTPServer = @import("zerver").HTTPServer;

fn helpMessage() []const u8 {
    return (
        \\Usage: zin [command] [option]
        \\
        \\Commands:
        \\
        \\  init        Initialize zin project at the current directory
        \\  build       Build zin project
        \\
        \\  help        Show this help messages.
        \\
        \\General Options:
        \\
        \\  -h, --help  Show this help messages.
    );
}

fn initProject() !void {
    try execute_command(.{"zig", "init"});
}

fn serve() !noreturn {
    const observe_dir = "src";

    const ip_addr = "0.0.0.0";
    var server = try HTTPServer.init("zig-out/html", ip_addr,  3000);
    defer server.deinit();

    var act = std.posix.Sigaction {
        .handler = .{
            .handler = struct {
                fn wrapper(_: c_int) callconv(.C) void {
                    @panic("accept SIGINT.\nbye ...\n");
                }
            }.wrapper,
        },
        .mask = std.posix.empty_sigset,
        .flags = 0,
    };
    try std.posix.sigaction(std.posix.SIG.INT, &act, null);

    var browser = try Browser.init(.chrome, server.getPortNumber());
    try browser.openHtml();
    var Monitor = try FileMonitor.init(observe_dir);
    defer Monitor.deinit();

    const fork_pid = try std.posix.fork();
    if (fork_pid == 0) {
        // child process
        try server.serve();
    } else {
        // parent process
        while(true) {
            if (Monitor.detectChanges()) {
                try execute_command(.{"zig", "build", "run"});
                try browser.reload();
            }
            std.time.sleep(1000000000);
        }
    }
}

pub fn main() !void {
    var args = std.process.args();
    _ = args.next() orelse "zframe";
    if(args.next()) |arg| {
        if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "help")) {
            std.debug.print(helpMessage(), .{});
        }
        else if (std.mem.eql(u8, arg, "init")) {
            if(args.next()) |project_name| {
                }
            }
        }
        else if (std.mem.eql(u8, arg, "build")) {
            try execute_command(.{"zig", "build", "run"});
            if(args.next()) |option| {
                if (std.mem.eql(u8, option, "serve")) {
                    try serve();
                } else if (std.mem.eql(u8, option, "-h")) {

                }
            }
        } else {
            std.debug.print("Invalid command: {s}\n", .{arg});
            std.debug.print(helpMessage(), .{});
        }
    }
}

fn execute_command(command: anytype) !void {
    var arena_allocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const fork_pid = try std.posix.fork();
    if (fork_pid == 0) {
        // child process
        const err = std.process.execve(arena_allocator.allocator(), &command, null); // noreturn if success
        std.debug.print("{s}\n", .{@errorName(err)});
    } else {
        // parent process
        const wait_result = std.posix.waitpid(fork_pid, 0);
        if (wait_result.status != 0) {
            std.debug.print("exit code: {}\n", .{wait_result.status});
        }
    }
}
