const std = @import("std");
const IN = std.os.linux.IN;

pub const FileMonitor = struct {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    root_path: []const u8,
    fd: i32,
    // monitors: std.ArrayList(i32),
    monitors: std.StringHashMap(i32),

    pub fn init(dir_path: []const u8) !FileMonitor {
        std.debug.print("file-monitor watching {s}...\n", .{dir_path});
        const fd = try std.posix.inotify_init1(0);

        var self = FileMonitor {
            .root_path = dir_path,
            .fd = fd,
            .monitors = std.StringHashMap(i32).init(alloc),
        };
        try self.addMonitor(dir_path);
        return self;
    }

    pub fn deinit(self: *FileMonitor) void {
        // _ = std.os.linux.inotify_rm_watch(self.fd, self.watcher);
        _ = std.os.linux.close(self.fd);
        _ = gpa.deinit();
    }

    fn addMonitor(self: *FileMonitor, path:[]const u8) !void {
        const wd = try std.posix.inotify_add_watch(self.fd, path, IN.CREATE | IN.DELETE | IN.MODIFY | IN.MOVE_SELF | IN.MOVE);
        try self.monitors.put(path, wd);

        var root = try std.fs.cwd().openDir(path, .{.iterate=true});
        defer root.close();
        var walker = try root.walk(alloc);
        while (try walker.next()) |entry| {
            switch(entry.kind) {
                .directory => {
                    std.debug.print("dir:{s}\n", .{try std.fmt.allocPrintZ(alloc, "{s}/{s}", .{path, entry.path})});
                    try self.addMonitor(try std.fmt.allocPrintZ(alloc, "{s}/{s}", .{path, entry.path}));
                },
                else => {},
            }
        }
    }

    fn removeMonitor(self: *FileMonitor, path:[]const u8) !void {
        const kv = self.monitors.fetchRemove(path).?;
        std.debug.print("{any}", .{kv});
        //
        // var root = try std.fs.cwd().openDir(path, .{.iterate=true});
        // defer root.close();
        // var walker = try root.walk(alloc);
        // while (try walker.next()) |entry| {
        //     switch(entry.kind) {
        //         .directory => {
        //             // std.debug.print("dir:{s}\n", .{try std.fmt.allocPrintZ(alloc, "{s}/{s}", .{path, entry.path})});
        //             try self.addMonitor(try std.fmt.allocPrintZ(alloc, "{s}/{s}", .{path, entry.path}));
        //         },
        //         else => {},
        //     }
        // }
    }

    pub fn detectChanges(self: *FileMonitor) bool {
        var buf:[256]u8 = undefined;
        while(true) {
            if (std.posix.read(self.fd, &buf)) |_| {
                var event = @as(*std.os.linux.inotify_event, @ptrCast(@alignCast(buf[0..])));
                switch (event.mask) {
                    IN.CREATE | IN.ISDIR => {
                        const path = std.fmt.allocPrintZ(alloc, "{s}/{s}", .{self.root_path, event.getName().?}) catch {
                            return false;
                        };
                        std.debug.print("created: {s},\tpath: {s}\n", .{event.getName().?, path});
                        self.addMonitor(self.root_path) catch {
                            return false;
                        };
                    },
                    IN.DELETE | IN.ISDIR => {
                        std.debug.print("deleted: {s}\n", .{event.getName().?});
                        // const path = std.fmt.allocPrintZ(alloc, "{s}/{s}", .{self.root_path, event.getName().?}) catch {
                        //     return false;
                        // };
                        // self.removeMonitor(path) catch {
                        //     return false;
                        // };
                    },
                    IN.MODIFY => {
                        std.debug.print("event: {s}\n", .{event.getName().?});
                    },
                    IN.MOVE_SELF => {},
                    IN.MOVE => {},
                    else => {},
                }
                return true;
            } else |e| {
                std.debug.print("error: {s}\n", .{@errorName(e)});
            }
        }
    }
};
