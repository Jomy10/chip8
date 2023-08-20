extern fn getTime() u64;

pub fn timestamp() i64 {
    return @bitCast(i64, getTime());
}

pub const WebTimer = struct {
    started: u64,
    previous: u64,

    pub fn start() !WebTimer {
        const current = getTime();
        return WebTimer{
            .started = current,
            .previous = current,
        };
    }

    pub fn read(self: *WebTimer) u64 {
        const current = getTime();
        return current - self.started;
    }

    pub fn reset(self: *WebTimer) void {
        const current = getTime();
        self.started = current;
    }
};
