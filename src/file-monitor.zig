const std = @import("std");

pub const FileMonitor = struct {
    var meta: std.fs.File.Stat = undefined;
    dirName: []const u8,
    size: u64,
    last_modified: i128,

    pub fn init(dirName: []const u8) !FileMonitor {
        std.debug.print("file-monitor watching {s}...\n", .{dirName});
        var dir = try std.fs.cwd().openDir(dirName, .{});
        defer dir.close();
        const stat = try dir.stat();
        var self = FileMonitor {
            .dirName = dirName,
            .size = stat.size,
            .last_modified = stat.mtime,
        };
        _=&self;
        return self;
    }

    pub fn detectChanges(self: *FileMonitor) bool {
        if (std.fs.cwd().openDir(self.dirName, .{})) |*dir| {
            defer @constCast(dir).close();
            const stat = dir.stat() catch return false;
            // if (self.size != stat.size and self.last_modified != stat.mtime) {
            if (self.size != stat.size) {
                std.debug.print("detect!\n", .{});
                self.size = stat.size;
                self.last_modified = stat.mtime;
                return true;
            } else {
                return false;
            }
        } else |err| {
            switch (err) {
                // ファイルが空だと起こる
                error.FileNotFound => return false,
                else => {
                    std.debug.print("{s}\n", .{@errorName(err)});
                    return false;
                },
            }
        }
    }
};
