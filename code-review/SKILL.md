---
name: code-review
description: Review C++ code in the mipilot autonomous driving project. Checks for safety-critical bugs (null pointers, bounds access, use-after-move, memset on non-POD, dangling references, buffer overflow), concurrency issues (data races, lock ordering, atomic misuse, return-after-lock), logic bugs (missing break, operator typos, uninitialized variables), and project conventions (macro usage, error handling patterns, Google style). Use this skill whenever the user asks to review, audit, check, or find bugs in any C++ file under the mipilot/ directory, even if they don't explicitly say "code review". Also use when users paste C++ code snippets from this project and ask for feedback.
---

# Code Review Skill for mipilot

## Project Context

This is a **safety-critical** C++ autonomous driving codebase built with Bazel. Code here ultimately controls a vehicle — bugs can have real-world consequences. The project follows Google C++ style guide with project-specific macros and conventions described below.

### Architecture Overview

The codebase is organized into several major modules under `mipilot/ados/`:

| Module | Role |
|--------|------|
| **em** (Execution Manager) | Process lifecycle manager across multiple SoCs. Manages child process start/stop, health monitoring, function group switching, mode transitions (Normal/Standby/Calibration), error restart, MCU status reporting. Hosts communicate via ZeroMQ. |
| **common** | Shared utilities: `ThreadSafeMap`, `ThreadPool`, `Status`/`StatusOr`, `RTSafeMutex`, timers, OS abstractions, logging macros. |
| **runtime** | Node lifecycle framework: `ManagedNode` state machine, `NodeContext`/`ProcessContext`, channel management, end-to-end latency tracking. |
| **sensors** | Hardware driver layer: GNSS (Novatel), CAN (SocketCAN), camera, IMU, USS. Each driver follows a unified state machine model with factory pattern. |
| **platform** | Hardware abstraction: `Channel`/`ChannelManager` for data transport, `BufferBase`/`BufferPool` for memory management, `Tensor`/`MemoryOp` for compute, NvSci engine integration. |

## How to Review

Follow this order — it mirrors decreasing severity:

1. **Understand the scope**: Read the file top-to-bottom. Identify the module's role, data flow (inputs → transforms → outputs), and threading model.
2. **Safety-critical sweep** (Priority 1): Check for memory safety, resource lifetime, and correctness bugs.
3. **Concurrency sweep** (Priority 2): Check for data races, deadlocks, and atomic ordering.
4. **Logic & robustness sweep** (Priority 3): Check for edge cases, error handling gaps, and defensive coding.
5. **Style & convention sweep** (Priority 4): Check macro usage, naming, and formatting.

**Critical rule**: For every potential issue, **trace the full data path** before reporting it. Confirm whether the issue actually manifests at runtime. This project values precision over recall — a false positive erodes trust. Clearly label each finding as:

- 🔴 **Bug**: Confirmed or highly likely real defect
- 🟡 **Warning**: Potential issue depending on runtime conditions
- 🔵 **Suggestion**: Defensive improvement, style, or readability

---

## Priority 1: Safety-Critical Checks

### 1.1 Null Pointer Dereference
- Check all raw pointers and `shared_ptr` before dereference.
- The project uses `ADS_CHECK_NOTNULL(ptr)` and `EM_CHECK(ptr != nullptr)` for fatal assertions. These crash on null — they're guards, not graceful handling.
- Watch for: pointer returned from map lookups (`find()` → `end()` check), config queries (`FindHostByName`, `FindNodeConfigByName`, etc.), and factory functions.

**False positive to avoid**: `std::make_unique<T>()` never returns nullptr (it throws `std::bad_alloc`). So `EM_CHECK(ptr != nullptr)` right after `make_unique` is redundant but not a bug. (~10 occurrences across the codebase — ignore these.)

### 1.2 memset on Non-POD Structs ⚠️ HIGH FREQUENCY
- `memset(&struct_var, 0, sizeof(struct_var))` is **undefined behavior** when the struct contains non-trivial members (`std::string`, `std::vector`, `shared_ptr`, etc.).
- This causes **heap corruption** because it zeroes out internal pointers/metadata of STL objects.
- **Real example**: sensors/gnss/novatel_gnss.cc uses `memset` to clear structs containing `std::string` — 4 occurrences, all causing UB.
- **Fix**: Use aggregate initialization `MyStruct s = {};` or write a proper `Reset()` method.
- This pattern is especially common in driver code porting from C.

### 1.3 Dangling References
- **Reference members binding to constructor parameters**: If a constructor takes `const std::string& name` and stores it as `const std::string& name_` (reference member), the member becomes a dangling reference if the caller passes a temporary or a string that goes out of scope.
- **Fix**: Store by value (`std::string name_`) or use `std::string_view` with clear lifetime documentation.
- **Real example**: platform/channel `Channel::name_` was a const reference binding to a constructor parameter.

### 1.4 Buffer Overflow from Mismatched Constants
- Check that buffer sizes and read limits use the **same** constant. A buffer of size N but a read limit of 2N is an overflow.
- **Real example**: sensors used a 4096-byte buffer but allowed reads up to 8192.
- Pay special attention to serial/socket receive buffers where external data arrives.

### 1.5 Bounds Checking
- Verify all `vector[]`, `array[]`, and protobuf `repeated` field index accesses.
- Loop variables: confirm the loop bound matches the container being indexed.
- Any index derived from external data (protobuf fields, config values, user input) needs bounds validation.
- `std::vector::at()` is preferred over `[]` for safety, but this project generally uses `[]` — so manual bounds checks matter.

### 1.6 Use-After-Move
- After `std::move(x)`, the variable `x` is in a valid-but-unspecified state. Using it afterward is a bug.
- Common pattern in this project: `std::move(fail_msg)` passed to event upload, then `fail_msg` used again later.

### 1.7 Resource Lifetime Across Async
- When `mipilot::ados::common::os::Async()` captures `this` or raw pointers, the referenced object must outlive the async task.
- Watch for: lambdas capturing `this` in signal handlers, `Finally` cleanup closures, and callbacks registered across threads.
- `std::bind(&Class::Method, this, ...)` in `Async()` calls — if `this` is destroyed before the future completes, it's use-after-free.
- **Best practice in this project**: Capture `weak_ptr` + `lock()` in async callbacks (used extensively in runtime module — this is the correct pattern).

### 1.8 Missing Return Statement
- Non-void functions that don't return a value on all paths cause **undefined behavior**.
- **Real example**: `ThreadSafeMap::emplace()` had a path with no `return` statement.
- Pay special attention to template wrapper classes that forward to internal containers.

### 1.9 System Call Return Value Checking
- All system calls (`ioctl`, `socket`, `bind`, `connect`, `open`, `read`, `write`, `close`, `mmap`) must have their return values checked.
- Unchecked `ioctl` can silently fail, leaving hardware in an unknown state — critical for sensors.
- **Real example**: sensors/can `ioctl` return value was not checked after configuring SocketCAN interface.
- Unchecked `socket()` returns -1 on failure; using -1 as fd leads to cascading errors.

### 1.10 Integer Safety
- `static_cast<size_t>(negative_int)` wraps to a huge number — check for potentially negative source values.
- `static_cast<int>(uint64_t)` loses high bits — check for truncation.
- Protobuf `int32` fields used as size/index: validate non-negative before use.
- `int8_t` used as `memcpy` length parameter — likely a bug if the value represents a size.

### 1.11 Float Arithmetic
- Watch for division by zero, NaN propagation, and precision loss in `double` → `float` conversions.
- `float::max() * anything > 1.0` overflows to infinity silently.

---

## Priority 2: Concurrency Checks

### 2.1 Data Races — General Pattern
This project uses fine-grained locking. Each mutex protects specific members:

| Mutex | Protects |
|-------|----------|
| `child_process_mutex_` | `child_processes_` map and related state |
| `fg_mutex_` | Function group operations |
| `other_host_mutex_` | Remote host state maps |
| `execution_monitor_mutex_` | `execution_monitor_` unique_ptr |
| `cur_host_status_mutex_` | MCU status reporting state |
| `session_mutex_` | Session data and file writes |
| `switch_mode_mutex_` | Mode transition operations |

**What to check**:
- Any access to the protected members listed above **without** holding the corresponding lock is a data race.
- `std::atomic` variables (`em_state_`, `em_mode_`, `restart_state_`, etc.) are safe for individual reads/writes, but **compound operations** (read-then-write) need CAS (`compare_exchange_strong`) or a mutex.
- The `try_to_lock` pattern (`std::unique_lock<std::mutex> lock(mtx, std::try_to_lock)`) intentionally skips work if the lock is contended — this is by design, not a bug.

### 2.2 Return-After-Lock Anti-Pattern ⚠️ HIGH FREQUENCY
- **Pattern**: A function acquires a lock, gets a pointer/iterator/reference to lock-protected data, then returns it to the caller. Once the function returns, the lock is released, and the caller holds a **dangling reference to unprotected data**.
- **Real examples**:
  - `ThreadSafeMap` returning iterators — invalid after lock release
  - `ProcessContext::GetChannelHandlers()` returning raw pointer to map data after lock release
- **Fix**: Return by value (copy), or require the caller to hold the lock (pass `unique_lock&` as parameter).

### 2.3 Plain bool Instead of std::atomic for Cross-Thread Flags
- If a `bool` member is written by one thread and read by another, it **must** be `std::atomic<bool>`.
- **Real example**: `WarmUp::is_warm_up_` was a plain `bool` accessed from multiple threads.
- Watch for: stop flags, ready flags, initialization flags, and warm-up indicators.
- Note: `std::atomic<bool>` is the minimum — for flags set once and read many times, `std::atomic` with `memory_order_release`/`memory_order_acquire` suffices.

### 2.4 Lock Ordering & Deadlocks
- If multiple mutexes are held simultaneously, they must always be acquired in the same order.
- Look for nested `lock_guard` / `unique_lock` scopes.

### 2.5 Signal Handler Safety
- Signal handlers should only call async-signal-safe functions (POSIX standard).
- Logging (`EM_INFO`, `ADS_INFO`) is **not** async-signal-safe (involves memory allocation, locks). Using them in signal handlers is technically undefined behavior but is an accepted trade-off in this project for debugging — flag it as 🟡 Warning, not 🔴 Bug.

### 2.6 Async Future Handling
- `std::future::get()` blocks and can only be called once. Calling it on an invalid future is undefined behavior.
- Always check `.valid()` before `.get()` when the future might not have been assigned.

---

## Priority 3: Logic & Robustness

### 3.1 Missing break in switch/case ⚠️ HIGH FREQUENCY
- Every `case` must end with `break`, `return`, `continue`, or `[[fallthrough]]`.
- Unintended fall-through is a common bug, especially in state machine handling.
- **Real example**: `ManagedNode` switch case in runtime module missing `break`, causing fall-through into the next case.
- When fall-through is intentional, it must be annotated with `[[fallthrough]]` or a comment.

### 3.2 Operator Overload Typos
- In `operator=`, watch for `==` (comparison) used instead of `=` (assignment). This compiles fine but does nothing.
- **Real example**: `TensorElement::operator=` used `mem_type_ == other.mem_type_` instead of `mem_type_ = other.mem_type_`.
- Check all assignment operators for this class of typo.

### 3.3 Uninitialized Variables on Error Paths
- When a function declares a `Status` or result variable and only initializes it inside a conditional branch, the variable may be uninitialized on the else path.
- **Real example**: `ManagedNode::Init()` — when `weak_ptr::lock()` fails, the `status` variable was returned uninitialized.
- **Fix**: Always initialize status variables at declaration: `Status status = Status::kError;`

### 3.4 Error Path Completeness
- Functions that return `bool` for success/failure: check that all failure paths log an error and clean up properly.
- **`EM_REPLY_ERR` vs `EM_REPLY_ERR_RETURN` confusion**: `EM_REPLY_ERR` sets reply code but does NOT return. If the intent is to stop execution on error, `EM_REPLY_ERR_RETURN` must be used instead. Check every `EM_REPLY_ERR` call — if code after it should not execute on failure, it's a missing-return bug.
- `Finally` (RAII defer): verify the cleanup lambda captures the right variables and the cleanup logic is correct for all exit paths.

### 3.5 Counter / Statistics Bugs
- If a counter is incremented in `Allocate()` but never decremented in `Release()`, usage statistics will be wrong.
- **Real example**: `BufferPool::count_` only incremented, never decremented — `GetUsage()` returned cumulative count, not current usage.

### 3.6 `strerror(errno)` Thread Safety ⚠️ HIGH FREQUENCY (ALL MODULES)
- `strerror()` is not thread-safe (returns a static buffer shared across threads). Use `strerror_r()` instead.
- Also: when a POSIX function returns an error code directly (like `pthread_join` returning `rc`), use `strerror(rc)`, NOT `strerror(errno)`. The two can differ.
- This is the **most frequently recurring issue** across the entire codebase (~20+ occurrences).

### 3.7 Empty String as Network Address
- If a config lookup returns an empty string and it's passed to `inet_addr()`, the result is `INADDR_NONE` (0xFFFFFFFF = broadcast address). This can cause unintended network behavior.
- Always validate network address strings before use.

### 3.8 Protobuf Field Access
- `has_xxx()` should be checked before accessing optional fields.
- `repeated` field iteration: use `.size()` or range-for, not raw index without bounds.

### 3.9 Process Lifecycle
- Child processes go through: Uninitialized → Starting → Running → Terminating → Terminated.
- State checks should cover all possible states, not just the happy path.
- `WaitPid()` must handle: return 0 (no child exited), -1 with ECHILD (no children), -1 with other errno, and positive pid.

---

## Priority 4: Style & Convention

### 4.1 Project Macros — Correct Usage
| Macro | When to Use |
|-------|-------------|
| `ADS_CHECK(cond)` / `EM_CHECK(cond)` | Invariants that should never be false. Crashes on failure — don't use for expected errors. |
| `ADS_CHECK_NOTNULL(ptr)` | Pointer invariants. |
| `ADS_RETURN_IF_ERROR(expr)` | Early return on error status — propagates errors cleanly. **Recommended pattern.** |
| `ADS_DEFINE_FINITE_LOOP_CHECKER(var)` + `ADS_CHECK_FINITE_LOOP(var, N)` | Every `while(true)` or potentially-infinite loop. N should be a reasonable upper bound. **Excellent practice — every loop that could spin should use this.** |
| `ADS_UNUSED(var)` | Suppress unused variable warnings. |
| `ADS_UNLIKELY(cond)` / `ADS_LIKELY(cond)` | Branch prediction hints for error/hot paths. |
| `EM_REPLY_ERR_RETURN(reply, code, msg)` | Set reply and return in RPC handlers. |
| `EM_REPLY_ERR(reply, code, msg)` | Set reply without returning — **be careful**, code continues! |
| `ADS_DISALLOW_COPY_AND_ASSIGN(Class)` | In `private:` section of non-copyable classes. |
| `Finally` | RAII defer — like Go's `defer`. Ensures cleanup on all exit paths. |

### 4.2 Common Anti-Patterns to Flag

| Anti-Pattern | Why It's Bad | Fix |
|-------------|-------------|-----|
| `static const int kFoo = 42;` in headers | Each TU gets its own copy — ODR violation risk | Use `inline constexpr` |
| `using namespace foo;` at file scope in headers | Pollutes every includer's namespace | Use at function scope or in anonymous namespace in .cc |
| `ADS_ERROR(...)` for non-error conditions | Misleading log levels, alarm fatigue | Use `ADS_WARN` or `ADS_INFO` |
| `std::thread t(...); t.detach();` | No join, no cleanup, no error handling, potential resource leak | Use ThreadPool or store and `join()` |
| `socket fd` without RAII or `close()` in all error paths | File descriptor leak | Use RAII wrapper or `Finally` |
| `map[key]` to check existence | Creates default entry if key missing | Use `find()` + `end()` check |

### 4.3 Google C++ Style
- Line length ≤ 80 characters
- Pointer/reference alignment: `int* foo` (left-aligned)
- Include order: C system → C++ standard → third party → mipilot headers
- `using` declarations should be at function scope, not file scope (except in .cc files in anonymous namespaces)
- Namespace closing comments: `}  // namespace foo`

### 4.4 Naming
- Classes: `PascalCase`
- Methods: `PascalCase`
- Variables: `snake_case`
- Member variables: `snake_case_` (trailing underscore)
- Constants: `kPascalCase`
- Enums: `kPascalCase` values

---

## Good Patterns to Acknowledge

When you see these patterns, note them as positive — reinforce good practices:

| Pattern | Where Used | Why It's Good |
|---------|-----------|---------------|
| `weak_ptr` capture + `lock()` in async callbacks | runtime, em | Prevents use-after-free when owner is destroyed before callback fires |
| `RTSafeMutex` (priority inheritance) | common, runtime | Prevents priority inversion in real-time threads |
| `ADS_DEFINE_FINITE_LOOP_CHECKER` | em, runtime | Guarantees loops terminate; production builds break instead of crash |
| `StatusOr<T>` | common | Type-safe error propagation — can't accidentally use an error as a value |
| `BufferPool` with RAII custom deleter | platform | `shared_ptr` custom deleter auto-returns buffer to pool — no leak possible |
| Factory pattern for drivers | sensors | Config-driven instantiation, clean extensibility |
| CAS (`compare_exchange_strong`) for state transitions | em, runtime | Lock-free, correct atomic state machine transitions |
| `Finally` RAII defer | em | Like Go's `defer` — ensures cleanup runs on all exit paths |
| `ADS_RETURN_IF_ERROR` | common, sensors | Clean error propagation without deep nesting |

---

## Output Format

Structure your review as follows:

```
## Review Summary
Brief overview: what the file does, key findings count by severity.

## Findings

### 🔴 Bug #1: [Short title]
**File**: path/to/file.cc#L123-L130
**Description**: What the bug is and why it's a bug.
**Evidence**: Trace the data flow that leads to the bug.
**Suggested Fix**: How to fix it (code snippet if appropriate).

### 🟡 Warning #1: [Short title]
(same structure)

### 🔵 Suggestion #1: [Short title]
(same structure)

## Good Practices Noted (optional)
Patterns that are well-implemented and should be maintained.

## No-Issue Notes (optional)
Things that look suspicious but are actually fine, with reasoning.
```

Keep the review focused — don't pad with trivial style nits if there are real bugs to discuss. Prioritize findings that matter for correctness and safety.
