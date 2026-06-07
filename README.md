# SwiftletModelPerformanceTestSuite

In-memory performance benchmarks comparing **[SwiftletModel](https://github.com/KazaiMazai/SwiftletModel)** against the common persistence options on Apple platforms:

| Engine | What it is | Backing |
|---|---|---|
| **SwiftletModel** | In-memory, value-type, indexed object graph | RAM (Swift) |
| **SwiftData** | Apple's persistence framework | SQLite (`:memory:`) |
| **Realm** | Realm Swift | realm-core (C++) |
| **SQLiteData** | Point-Free's library (GRDB + StructuredQueries) | SQLite (`:memory:`) |
| **GRDB** | GRDB used directly | SQLite (`:memory:`) |

Everything runs **purely in-memory** so the comparison is about the engines' own data structures and query paths, not disk I/O.

## What it measures

Each engine is exercised on the same deterministic, seeded dataset of Users: (`firstName`, `surname`, `age` rows with a unique-indexed `id`), across these operations:

| Operation | Description |
|---|---|
| `ID lookup` | fetch one row by primary key |
| `equal` | `field == value` |
| `not equal` | `field != value` |
| `compare` | `field > threshold` |
| `sort` | order all rows by a field |
| `insert` | bulk insert N rows |
| `update` | mutate + persist N rows (no prior read) |

Filter/sort operations are run for both **`Int`** and **`String`** fields. Each engine is benchmarked in the configurations that matter for it:

- **SwiftletModel** — `indexed` (`@Index`/`@HashIndex` on the queried fields) and `unindexed` (full scan).
- **Realm / SwiftData** — `default` and `indexed` (`@Persisted(indexed:)` / `#Index`).
- **SQLiteData / GRDB** — `default` (no secondary index).

Measurement uses `XCTest`'s `measure` (10 samples). Test cases are generated at runtime per size via a small Obj-C `ParametrizedTestCase` base (the Quick trick), and each run appends a row per case to `BenchmarkResults/results.csv` (avg / min / max / stddev in ms).

## Running

The whole suite runs headless on macOS via SwiftPM — no app host, no simulator:

```bash
swift test -c release
```

> **Always use `-c release`.** A debug build compiles the Swift layers (SwiftletModel, RealmSwift, GRDB) unoptimized (`-Onone`), which penalizes them by 2–10× while leaving the C/C++ engines untouched — i.e. it produces *distorted*, not just slower, numbers.

Configure the dataset size(s) in `Tests/SwiftletModelPerformanceTests/BenchmarkCase.swift`:

```swift
static let sizes = [10, 100, 1_000, 10_000, 100_000]   // one table is produced per size
```

Results are written to `BenchmarkResults/results.csv` at the package root.

## Printing the results

A dependency-free CLI renders the CSV as a comparison table:

```bash
swift run bench-report                       # default CSV, avg ms, Int reads
swift run bench-report path/to/results.csv   # explicit CSV path
swift run bench-report --type string         # String variant for typed reads
swift run bench-report --metric min          # min instead of avg
swift run bench-report --by-engine           # per-engine scaling tables
```

**Two layouts:**

- **Default** — one table *per size*: rows = operations, columns = engines. Highlights the fastest engine per row (bold green in a terminal) and marks every engine that wins ≥1 operation in a `Winner` row.
- **`--by-engine`** — one table *per engine*: rows = item counts, columns = operations. Shows how each engine scales with dataset size.

## Results

Apple Silicon, macOS, **Release**, in-memory, 10 samples per measurement, single run, swept over **10 / 100 / 1,000 / 10,000 / 100,000** rows. Values are **avg ms** (lower is better); `Int` shown for typed reads. **Bold = fastest in row.**

### Comparison at 100,000 rows

| Operation | SwiftletModel·idx | SwiftletModel·raw | GRDB | SQLiteData | Realm | Realm·idx | SwiftData | SwiftData·idx |
|---|--:|--:|--:|--:|--:|--:|--:|--:|
| ID lookup | **0.00** | **0.00** | 0.09 | 0.21 | 0.01 | 0.01 | 0.21 | 0.35 |
| equal | **4.23** | 66.02 | 9.90 | 10.01 | 6.49 | 5.89 | 50.42 | 54.40 |
| not equal | **48.93** | 112.72 | 84.07 | 56.98 | 85.62 | 90.54 | 933.55 | 956.94 |
| compare | **25.64** | 88.03 | 42.73 | 31.51 | 44.28 | 46.52 | 451.26 | 473.82 |
| sort | 130.89 | 422.15 | 118.13 | **81.03** | 119.93 | 126.96 | 991.42 | 1034.98 |
| insert | 1999.72 | 685.01 | 496.66 | 623.74 | **491.99** | 726.00 | 5206.21 | 5447.02 |
| update | 4522.19 | 1219.02 | 910.51 | 1555.32 | **57.14** | 172.00 | 3992.18 | 4110.33 |

### Scaling per engine (`--by-engine`)

`swift run bench-report --by-engine` prints one of these per engine — rows are item counts, columns are operations — so you can read each engine's scaling curve. (avg ms, Int reads)

**SwiftletModel · indexed** — point reads stay flat; indexed writes scale *super*-linearly (index upkeep):

| rows | ID lookup | equal | not equal | compare | sort | insert | update |
|--:|--:|--:|--:|--:|--:|--:|--:|
| 10 | 0.01 | 0.07 | 0.10 | 0.11 | 0.08 | 0.59 | 0.37 |
| 100 | 0.00 | 0.02 | 0.18 | 0.12 | 0.50 | 2.07 | 2.89 |
| 1,000 | 0.01 | 0.15 | 1.25 | 0.50 | 2.61 | 18.98 | 22.55 |
| 10,000 | 0.01 | 0.78 | 7.28 | 3.34 | 14.05 | 186.84 | 262.26 |
| 100,000 | 0.00 | 4.23 | 48.93 | 25.64 | 130.89 | 1999.72 | 4522.19 |

**SwiftletModel · unindexed** — no index, so even `equal`/`compare` scale ~linearly, but writes are cheap:

| rows | ID lookup | equal | not equal | compare | sort | insert | update |
|--:|--:|--:|--:|--:|--:|--:|--:|
| 10 | 0.01 | 0.06 | 0.04 | 0.08 | 0.12 | 0.14 | 0.17 |
| 100 | 0.00 | 0.15 | 0.24 | 0.34 | 0.91 | 1.35 | 1.71 |
| 1,000 | 0.00 | 1.63 | 2.57 | 1.90 | 4.78 | 8.41 | 12.00 |
| 10,000 | 0.00 | 9.09 | 12.47 | 11.42 | 38.53 | 64.91 | 108.40 |
| 100,000 | 0.00 | 66.02 | 112.72 | 88.03 | 422.15 | 685.01 | 1219.02 |

**GRDB · default**

| rows | ID lookup | equal | not equal | compare | sort | insert | update |
|--:|--:|--:|--:|--:|--:|--:|--:|
| 10 | 0.12 | 0.24 | 0.14 | 0.11 | 0.11 | 0.38 | 0.65 |
| 100 | 0.14 | 0.10 | 0.40 | 0.36 | 0.45 | 1.16 | 2.42 |
| 1,000 | 0.24 | 0.24 | 2.05 | 0.96 | 2.52 | 8.09 | 10.56 |
| 10,000 | 0.09 | 1.22 | 10.62 | 6.70 | 12.51 | 50.40 | 88.10 |
| 100,000 | 0.09 | 9.90 | 84.07 | 42.73 | 118.13 | 496.66 | 910.51 |

**SQLiteData · default**

| rows | ID lookup | equal | not equal | compare | sort | insert | update |
|--:|--:|--:|--:|--:|--:|--:|--:|
| 10 | 0.33 | 0.19 | 0.27 | 0.25 | 0.12 | 0.22 | 0.39 |
| 100 | 0.13 | 0.11 | 0.20 | 0.29 | 0.56 | 1.63 | 3.77 |
| 1,000 | 0.30 | 0.22 | 1.96 | 0.95 | 1.42 | 10.36 | 17.71 |
| 10,000 | 0.30 | 2.23 | 8.25 | 6.08 | 11.24 | 64.52 | 154.63 |
| 100,000 | 0.21 | 10.01 | 56.98 | 31.51 | 81.03 | 623.74 | 1555.32 |

**Realm · default** — `update` is the standout: ~57 ms at 100k while everyone else is in the *seconds*:

| rows | ID lookup | equal | not equal | compare | sort | insert | update |
|--:|--:|--:|--:|--:|--:|--:|--:|
| 10 | 0.02 | 0.05 | 0.08 | 0.09 | 0.09 | 0.37 | 0.32 |
| 100 | 0.02 | 0.04 | 0.20 | 0.11 | 0.52 | 1.48 | 0.20 |
| 1,000 | 0.02 | 0.30 | 2.53 | 2.01 | 3.04 | 6.56 | 0.70 |
| 10,000 | 0.01 | 1.29 | 12.42 | 5.93 | 14.56 | 51.15 | 5.32 |
| 100,000 | 0.01 | 6.49 | 85.62 | 44.28 | 119.93 | 491.99 | 57.14 |

**Realm · indexed**

| rows | ID lookup | equal | not equal | compare | sort | insert | update |
|--:|--:|--:|--:|--:|--:|--:|--:|
| 10 | 0.03 | 0.11 | 0.10 | 0.05 | 0.07 | 0.98 | 0.22 |
| 100 | 0.01 | 0.04 | 0.19 | 0.10 | 0.21 | 1.08 | 0.26 |
| 1,000 | 0.01 | 0.13 | 1.63 | 0.77 | 3.38 | 8.55 | 1.42 |
| 10,000 | 0.01 | 1.97 | 10.36 | 7.41 | 13.35 | 65.88 | 14.13 |
| 100,000 | 0.01 | 5.89 | 90.54 | 46.52 | 126.96 | 726.00 | 172.00 |

**SwiftData · default** — last on every read/insert; the gap widens with N (`not equal` reaches ~0.9 s):

| rows | ID lookup | equal | not equal | compare | sort | insert | update |
|--:|--:|--:|--:|--:|--:|--:|--:|
| 10 | 0.42 | 0.42 | 0.39 | 0.30 | 0.48 | 1.72 | 1.18 |
| 100 | 0.74 | 0.43 | 1.74 | 1.02 | 2.38 | 5.83 | 4.60 |
| 1,000 | 0.40 | 1.62 | 11.46 | 4.79 | 11.88 | 45.79 | 34.16 |
| 10,000 | 0.42 | 7.53 | 87.93 | 43.22 | 92.35 | 458.92 | 346.58 |
| 100,000 | 0.21 | 50.42 | 933.55 | 451.26 | 991.42 | 5206.21 | 3992.18 |

**SwiftData · indexed**

| rows | ID lookup | equal | not equal | compare | sort | insert | update |
|--:|--:|--:|--:|--:|--:|--:|--:|
| 10 | 0.56 | 0.32 | 0.45 | 0.75 | 1.13 | 2.22 | 1.49 |
| 100 | 0.52 | 0.28 | 2.27 | 1.10 | 3.63 | 7.80 | 4.92 |
| 1,000 | 0.22 | 1.35 | 10.98 | 7.75 | 13.71 | 46.14 | 35.21 |
| 10,000 | 0.60 | 9.61 | 91.75 | 48.21 | 98.37 | 483.82 | 441.63 |
| 100,000 | 0.35 | 54.40 | 956.94 | 473.82 | 1034.98 | 5447.02 | 4110.33 |

### Takeaways

- **SwiftletModel (indexed) wins every read except `sort`** — `ID lookup` (flat, O(1)), `equal` (4.2 ms at 100k vs SwiftData's 50), and even `not equal` / `compare` (it and SQLiteData trade these run-to-run; here SwiftletModel takes them). Its in-memory keyed store + indexes are unbeatable for *finding* rows.
- **`sort` goes to SQLiteData** at scale (81 ms vs 131 ms at 100k) — SQLite's native C sort is the fastest in-RAM, with GRDB/Realm/SwiftletModel clustered behind.
- **Realm owns `update`, overwhelmingly** — 57 ms at 100k while *everyone else is in the seconds* (0.9–4.5 s). In-place mutation of live objects barely cares about N.
- **Insert: Realm ≈ GRDB** (~0.49 s at 100k), then SQLiteData and unindexed SwiftletModel; SwiftData is ~5 s.
- **SwiftletModel's indexed writes are its weak spot at scale.** At 100k, indexed insert is **2.0 s** and update **4.5 s** — 3–4× its *unindexed* self (0.69 s / 1.2 s) and the slowest writes in the table — because index maintenance scales super-linearly. Skip the index and writes are competitive, but reads fall off. **You pick one config.**
- **SwiftData is last on every read and insert, by ~8–10× at scale** (`not equal` 0.93 s, insert 5.2 s at 100k). It runs the *same* `:memory:` SQLite as SQLiteData/GRDB — both far faster — so the cost is its object-materialization layer, not the database.
- **Scaling shapes:** `ID lookup` flat (O(1)); indexed `equal` scales gently while *unindexed* `equal` is ~linear; most reads/writes are ~linear, except SwiftletModel's indexed writes (super-linear).

## Methodology & caveats

- **Release only** (see above). Cross-module optimization isn't enabled because it conflicts with the testability needed by the test target; `-O` + whole-module is the representative max.
- **In-memory.** SwiftData/SQLite indexes mainly optimize disk I/O, so on disk the comparison would shift.
- **Noise.** Fast reads (`equal`/`compare`/`not equal`) complete in well under a millisecond and carry ~20–80% run-to-run variance at 10 samples — treat them to ~1 significant figure and prefer `--metric min`. `sort`, `insert`, `update`, `ID lookup` are stable to ~5%. Rankings are stable across runs even where exact values aren't.
- **Result semantics differ:** SwiftletModel/SQLiteData/GRDB/SwiftData return value copies; Realm returns lazy live objects (cheap to fetch, cost deferred to access).
- This is a **micro-benchmark of a synthetic workload** — use it to understand the engines' shapes, not as a single verdict.

## Project layout

```
Package.swift
Sources/
  ParametrizedXCTestCase/        # Obj-C runtime-parametrized XCTest base
  bench-report/                  # CSV → table CLI
Tests/SwiftletModelPerformanceTests/
  BenchmarkCase.swift            # sizes, registration, measure helpers
  BenchmarkDataset.swift         # seeded dataset + query targets
  BenchmarkEntities.swift        # SwiftletModel entities + in-memory store builders
  BenchmarkResultsWriter.swift   # appends results to CSV
  <Engine>ReadTests.swift / <Engine>WriteTests.swift
  Support/                       # SwiftUser, RealmUser, name resources
```
