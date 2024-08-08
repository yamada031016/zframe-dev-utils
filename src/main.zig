const std = @import("std");
const Browser = @import("browser.zig").Browser;
const FileMonitor = @import("file-monitor.zig").FileMonitor;

pub fn main() !void {
    var browser = Browser.init(.chrome);
    try browser.openHtml();
    try browser.reload();
    const dir = std.fs.cwd();
    var Monitor = try FileMonitor.init("index.html", dir);
    while(true) {
        if (Monitor.detectChanges()) {
            try browser.reload();
        }
        std.time.sleep(1000000000);
    }
}
