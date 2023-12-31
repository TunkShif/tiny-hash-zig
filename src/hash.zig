const std = @import("std");
const Allocator = std.mem.Allocator;

const max_load_factor = 0.75;

const State = enum {
    empty,
    marked,
    deleted,
};

fn Entry(comptime V: type) type {
    return struct {
        key: ?[]const u8 = null,
        state: State = .empty,
        value: ?V = null,
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
            if (self.capacity == 0) return;
            self.allocator.free(self.entries);
        }

        pub fn get(self: *@This(), key: []const u8) ?*const V {
            if (self.size == 0) return null;
            const entry = self.findEntry(self.entries, self.capacity, key);
            if (entry.state == .empty) return null;
            return if (entry.value) |v| &v else null;
        }

        pub fn put(self: *@This(), key: []const u8, value: V) !bool {
            if (@as(f64, @floatFromInt(self.size + 1)) > @as(f64, @floatFromInt(self.capacity)) * max_load_factor) {
                const capacity = if (self.capacity < 8) 8 else self.capacity * 2;
                try self.resize(capacity);
            }

            var entry = self.findEntry(self.entries, self.capacity, key);
            const is_new_key = entry.state == .empty;
            if (is_new_key and entry.state != .deleted) {
                self.size += 1;
            }

            entry.key = key;
            entry.state = .marked;
            entry.value = value;

            return is_new_key;
        }

        pub fn delete(self: *@This(), key: []const u8) !bool {
            if (self.size == 0) return false;
            var entry = self.findEntry(self.entries, self.capacity, key);
            if (entry.state != .marked) return false;

            entry.key = null;
            entry.state = .deleted;
            entry.value = null;
            return true;
        }

        fn resize(self: *@This(), capacity: usize) !void {
            var entries = try self.allocator.alloc(E, capacity);
            for (entries) |*entry| {
                entry.key = null;
                entry.state = .empty;
                entry.value = null;
            }

            if (self.size != 0) {
                self.size = 0;
                for (self.entries) |entry| {
                    if (entry.state != .marked) continue;
                    var dest = self.findEntry(entries, capacity, entry.key.?);
                    dest.key = entry.key;
                    dest.state = entry.state;
                    dest.value = entry.value;
                    self.size += 1;
                }

                self.allocator.free(self.entries);
            }

            self.capacity = capacity;
            self.entries = entries;
        }

        fn findEntry(self: *@This(), entries: []E, capacity: usize, key: []const u8) *E {
            _ = self;
            var index: usize = hash(key) % capacity;
            var tombstone: ?*E = null;

            while (true) {
                const entry = &entries[index];

                switch (entry.state) {
                    .empty => {
                        return tombstone orelse entry;
                    },
                    .deleted => {
                        tombstone = entry;
                    },
                    .marked => {
                        if (std.mem.eql(u8, entry.key.?, key)) return entry;
                    },
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
    // TODO: write test cases
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var map = TinyHash(u8).init(allocator);
    defer map.deinit();

    const key = "c";

    _ = try map.put("bagel", 0);
    _ = try map.put("biscuit", 0);

    _ = try map.put("a", 0);
    _ = try map.put("b", 1);
    _ = try map.put("c", 2);
    _ = try map.put(key, 3);
    _ = try map.put("d", 4);
    _ = try map.put("e", 5);
    _ = try map.put("f", 6);
    _ = try map.put("g", 7);

    std.debug.print("capacity: {d} size: {d}\n", .{ map.capacity, map.size });

    var val = map.get("a");
    std.debug.print("a: {d}\n", .{val.?.*});

    val = map.get("non-exist");
    std.debug.print("?: {*}\n", .{val});

    _ = try map.delete("a");
    _ = try map.delete("b");
    _ = try map.delete("c");
    std.debug.print("capacity: {d} size: {d}\n", .{ map.capacity, map.size });
    std.debug.print("a: {*}\n", .{map.get("a")});
    std.debug.print("b: {*}\n", .{map.get("b")});
    std.debug.print("c: {*}\n", .{map.get("c")});

    _ = try map.put("h", 7);
    _ = try map.put("i", 7);
    _ = try map.put("j", 7);
    _ = try map.put("k", 7);
    _ = try map.put("l", 7);
    _ = try map.put("m", 7);
    _ = try map.put("n", 7);
    std.debug.print("capacity: {d} size: {d}\n", .{ map.capacity, map.size });
}
