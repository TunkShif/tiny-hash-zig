Hash data structure implemented in Zig, adapted from [Hash Tables - Crafting Interpreters][0].

# Usage

```zig
var map = TinyHash(u8).init(allocator);
defer map.deinit();

_ = try map.put("foo", 233);
_ = map.get("foo") orelse 0;
_ = try map.delete("foo");
```

# TODO
- [] Write test cases
- [] Zig module support

# Implementation Details

> TODO

[0]: https://craftinginterpreters.com/hash-tables.html
