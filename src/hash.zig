const std = @import("std");
const Allocator = std.mem.Allocator;

const max_load_factor = 0.75;

fn Entry(comptime V: type) type {
    return struct {
        key: ?[]const u8,
        value: ?V,
    };
}

pub fn TinyHash(comptime V: type) type {
    const E = Entry(V);
    return struct {
        size: usize,
        capacity: usize,
        entries: []E,
        allocator: Allocator,

        pub fn init(allocator: Allocator) @This() {
            return .{
                .size = 0,
                .capacity = 0,
                .entries = undefined,
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *@This()) void {
            if (self.capacity != 0) {
                self.allocator.free(self.entries);
            }
        }

        pub fn put(self: *@This(), key: []const u8, value: V) !bool {
            if (@as(f64, @floatFromInt(self.size + 1)) > @as(f64, @floatFromInt(self.capacity)) * max_load_factor) {
                const capacity = if (self.capacity < 8) 8 else self.capacity * 2;
                try self.resize(capacity);
            }

            var entry = self.findEntry(self.entries, self.capacity, key);
            const is_new_key = entry.*.key == null;
            if (is_new_key) {
                self.size += 1;
            }

            entry.key = key;
            entry.value = value;

            return is_new_key;
        }

        fn resize(self: *@This(), capacity: usize) !void {
            var entries = try self.allocator.alloc(E, capacity);
            for (entries) |*entry| {
                entry.key = null;
                entry.value = null;
            }

            if (self.size != 0) {
                for (self.entries) |entry| {
                    if (entry.key == null) continue;
                    var dest = self.findEntry(entries, capacity, entry.key.?);
                    dest.key = entry.key;
                    dest.value = entry.value;
                }

                self.allocator.free(self.entries);
            }

            self.capacity = capacity;
            self.entries = entries;
        }

        fn findEntry(self: *@This(), entries: []E, capacity: usize, key: []const u8) *E {
            _ = self;
            var index: usize = hash(key) % capacity;

            while (true) {
                const entry = &entries[index];
                if (entry.key == null or std.mem.eql(u8, entry.key.?, key)) {
                    return entry;
                }
                index = (index + 1) % capacity;
            }
        }
    };
}

// Zig has a builtin fnv hash function in std.hash.Fnv1a_32
// See: https://en.wikipedia.org/wiki/Fowler%E2%80%93Noll%E2%80%93Vo_hash_function
fn hash(key: []const u8) u32 {
    var hashed: u32 = 2166136261;

    for (key) |i| {
        const casted: u8 = @intCast(i);
        hashed ^= casted;
        hashed *%= 16777619;
    }

    return hashed;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();
    defer {
        _ = gpa.deinit();
    }

    var map = TinyHash(u8).init(allocator);
    defer map.deinit();

    const key = "c";

    _ = try map.put("a", 0);
    _ = try map.put("b", 1);
    _ = try map.put("c", 2);
    _ = try map.put(key, 3);
    _ = try map.put("d", 4);
    _ = try map.put("e", 5);
    _ = try map.put("f", 6);
    _ = try map.put("g", 7);

    std.debug.print("capacity: {d} size: {d}\n", .{ map.capacity, map.size });
}
