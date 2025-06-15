///Allow waiting for a duration while in a loop
const Self = @This();

duration: f64,
passed: f64 = 0,

pub fn update(self: *Self, interval_ns: f64) void {
    self.passed += interval_ns;
}

pub fn running(self: *const Self) bool {
    return self.passed < self.duration;
}
