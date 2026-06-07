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

Each case runs a short **rampup** (discarded warmup iterations to reach steady state — warm caches, lazy init, SQLite prepared-statement compilation) and then times a fixed number of iterations: **50 for reads, 20 for writes** (reads are cheap to repeat; writes rebuild a fresh store every iteration). It's a manual warmup+timed loop rather than XCTest's `measure`, for control over rampup and iteration count. Test cases are generated at runtime per size via a small Obj-C `ParametrizedTestCase` base (the Quick trick), and each run appends a row per case to `BenchmarkResults/results.csv` (avg / min / max / stddev in ms).

## Running

The whole suite runs headless on macOS via SwiftPM — no app host, no simulator:

```bash
swift test -c release
```

> **Always use `-c release`.** A debug build compiles the Swift layers (SwiftletModel, RealmSwift, GRDB) unoptimized (`-Onone`), which penalizes them by 2–10× while leaving the C/C++ engines untouched — i.e. it produces *distorted*, not just slower, numbers.

Configure the dataset size(s) in `Tests/SwiftletModelPerformanceTests/BenchmarkCase.swift`:

```swift
static let sizes = [10, 100, 1_000, 10_000]   // one table is produced per size
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

Apple Silicon, macOS, **Release**, in-memory, **rampup + 50 read / 20 write timed iterations**, single run, swept over **10 / 100 / 1,000 / 10,000** rows. Values are **avg ms** (lower is better); `Int` shown for typed reads. **Bold = fastest in row.**

### Comparison at 10,000 rows

| Operation | SwiftletModel·idx | SwiftletModel·raw | GRDB | SQLiteData | Realm | Realm·idx | SwiftData | SwiftData·idx |
|---|--:|--:|--:|--:|--:|--:|--:|--:|
| ID lookup | **0.00** | **0.00** | 0.02 | 0.04 | **0.00** | **0.00** | 0.06 | 0.05 |
| equal | **0.23** | 6.24 | 0.69 | 0.55 | 0.43 | 0.44 | 4.77 | 4.69 |
| not equal | **4.32** | 10.87 | 7.93 | 5.15 | 8.11 | 8.07 | 90.86 | 87.43 |
| compare | **2.23** | 8.38 | 3.94 | 2.69 | 4.00 | 3.98 | 41.31 | 42.97 |
| sort | 10.97 | 34.35 | 10.17 | **7.15** | 10.68 | 10.78 | 91.38 | 96.05 |
| insert | 171.37 | 60.65 | **46.55** | 58.74 | 49.27 | 65.24 | 454.05 | 469.77 |
| update | 254.93 | 105.60 | 85.71 | 150.86 | **5.18** | 13.43 | 353.32 | 387.25 |

### Scaling per engine (`--by-engine`)

`swift run bench-report --by-engine` prints one of these per engine — rows are item counts, columns are operations — so you can read each engine's scaling curve. (avg ms, Int reads)

**SwiftletModel · indexed** — point reads stay flat; indexed writes scale *super*-linearly (index upkeep):

| rows | ID lookup | equal | not equal | compare | sort | insert | update |
|--:|--:|--:|--:|--:|--:|--:|--:|
| 10 | 0.00 | 0.00 | 0.02 | 0.01 | 0.02 | 0.15 | 0.15 |
| 100 | 0.00 | 0.00 | 0.08 | 0.04 | 0.13 | 1.43 | 1.70 |
| 1,000 | 0.00 | 0.02 | 0.45 | 0.23 | 1.11 | 15.62 | 21.08 |
| 10,000 | 0.00 | 0.23 | 4.32 | 2.23 | 10.97 | 171.37 | 254.93 |

**SwiftletModel · unindexed** — no index, so even `equal`/`compare` scale ~linearly, but writes are cheap:

| rows | ID lookup | equal | not equal | compare | sort | insert | update |
|--:|--:|--:|--:|--:|--:|--:|--:|
| 10 | 0.00 | 0.01 | 0.01 | 0.01 | 0.02 | 0.05 | 0.07 |
| 100 | 0.00 | 0.07 | 0.11 | 0.08 | 0.31 | 0.51 | 0.77 |
| 1,000 | 0.00 | 0.63 | 1.08 | 0.84 | 4.11 | 5.42 | 10.22 |
| 10,000 | 0.00 | 6.24 | 10.87 | 8.38 | 34.35 | 60.65 | 105.60 |

**GRDB · default**

| rows | ID lookup | equal | not equal | compare | sort | insert | update |
|--:|--:|--:|--:|--:|--:|--:|--:|
| 10 | 0.03 | 0.02 | 0.03 | 0.03 | 0.03 | 0.08 | 0.10 |
| 100 | 0.03 | 0.03 | 0.10 | 0.06 | 0.11 | 0.48 | 0.87 |
| 1,000 | 0.03 | 0.10 | 0.82 | 0.41 | 1.00 | 4.54 | 8.67 |
| 10,000 | 0.02 | 0.69 | 7.93 | 3.94 | 10.17 | 46.55 | 85.71 |

**SQLiteData · default**

| rows | ID lookup | equal | not equal | compare | sort | insert | update |
|--:|--:|--:|--:|--:|--:|--:|--:|
| 10 | 0.04 | 0.03 | 0.03 | 0.03 | 0.03 | 0.08 | 0.16 |
| 100 | 0.04 | 0.03 | 0.08 | 0.05 | 0.09 | 0.58 | 1.55 |
| 1,000 | 0.04 | 0.08 | 0.54 | 0.27 | 0.72 | 5.73 | 15.06 |
| 10,000 | 0.04 | 0.55 | 5.15 | 2.69 | 7.15 | 58.74 | 150.86 |

**Realm · default** — `update` is the standout: ~5 ms at 10k while everyone else is 86–355 ms:

| rows | ID lookup | equal | not equal | compare | sort | insert | update |
|--:|--:|--:|--:|--:|--:|--:|--:|
| 10 | 0.00 | 0.01 | 0.01 | 0.01 | 0.02 | 0.15 | 0.07 |
| 100 | 0.00 | 0.01 | 0.09 | 0.04 | 0.10 | 0.58 | 0.20 |
| 1,000 | 0.00 | 0.05 | 0.80 | 0.39 | 1.02 | 5.14 | 0.66 |
| 10,000 | 0.00 | 0.43 | 8.11 | 4.00 | 10.68 | 49.27 | 5.18 |

**Realm · indexed**

| rows | ID lookup | equal | not equal | compare | sort | insert | update |
|--:|--:|--:|--:|--:|--:|--:|--:|
| 10 | 0.01 | 0.01 | 0.01 | 0.01 | 0.02 | 0.47 | 0.11 |
| 100 | 0.00 | 0.01 | 0.08 | 0.05 | 0.10 | 2.02 | 0.20 |
| 1,000 | 0.00 | 0.05 | 0.83 | 0.39 | 1.02 | 7.96 | 1.23 |
| 10,000 | 0.00 | 0.44 | 8.07 | 3.98 | 10.78 | 65.24 | 13.43 |

**SwiftData · default** — last on every read/insert; the gap widens with N (`not equal` ~91 ms at 10k):

| rows | ID lookup | equal | not equal | compare | sort | insert | update |
|--:|--:|--:|--:|--:|--:|--:|--:|
| 10 | 0.05 | 0.05 | 0.13 | 0.09 | 0.13 | 0.73 | 0.56 |
| 100 | 0.05 | 0.09 | 0.91 | 0.43 | 0.95 | 4.72 | 3.58 |
| 1,000 | 0.05 | 0.53 | 8.39 | 4.15 | 8.90 | 43.39 | 34.41 |
| 10,000 | 0.06 | 4.77 | 90.86 | 41.31 | 91.38 | 454.05 | 353.32 |

**SwiftData · indexed**

| rows | ID lookup | equal | not equal | compare | sort | insert | update |
|--:|--:|--:|--:|--:|--:|--:|--:|
| 10 | 0.06 | 0.05 | 0.14 | 0.09 | 0.14 | 0.74 | 0.58 |
| 100 | 0.06 | 0.08 | 0.95 | 0.44 | 1.00 | 4.54 | 3.71 |
| 1,000 | 0.06 | 0.53 | 8.61 | 4.25 | 9.09 | 43.83 | 35.24 |
| 10,000 | 0.05 | 4.69 | 87.43 | 42.97 | 96.05 | 469.77 | 387.25 |

### Takeaways

- **SwiftletModel (indexed) wins every read except `sort`** — `ID lookup` (~0, O(1)), `equal` (0.23 ms at 10k vs SwiftData's 4.8 — ~20×), `not equal` (4.3 vs SQLite's 5.2), and `compare` (2.2 vs 2.7). Its in-memory keyed store + indexes are unbeatable for *finding* rows.
- **`sort` goes to SQLiteData** (7.2 ms at 10k) — SQLite's native C sort is the fastest in-RAM, with GRDB / Realm / SwiftletModel clustered ~10–11 ms behind.
- **Realm owns `update`, overwhelmingly** — 5.2 ms at 10k while everyone else is 86–355 ms; it barely scales with N. In-place mutation of live objects.
- **Insert is a four-way cluster** — GRDB 46.6 ≈ Realm 49.3 ≈ SQLiteData 58.7 ≈ unindexed SwiftletModel 60.7 ms; SwiftData is ~454 ms.
- **SwiftletModel's indexed writes are its weak spot.** At 10k, indexed insert (171 ms) and update (255 ms) are ~3× / ~2.4× its *unindexed* self (61 / 106 ms) and the slowest writes outside SwiftData — index maintenance scales super-linearly. Skip the index and writes are competitive, but reads fall off. **You pick one config.**
- **SwiftData is last on every read and insert, by ~8–10×** (`not equal` 91 ms, insert 454 ms at 10k). It runs the *same* `:memory:` SQLite as SQLiteData/GRDB — both far faster — so the cost is its object-materialization layer, not the database.
- **Scaling shapes:** `ID lookup` flat (O(1)); indexed `equal` scales gently while *unindexed* `equal` is ~linear; most reads/writes are ~linear, except SwiftletModel's indexed writes (super-linear).

## Methodology & caveats

- **Release only** (see above). Cross-module optimization isn't enabled because it conflicts with the testability needed by the test target; `-O` + whole-module is the representative max.
- **In-memory.** SwiftData/SQLite indexes mainly optimize disk I/O, so on disk the comparison would shift.
- **Noise.** The sub-millisecond reads (`equal`/`compare`/`ID lookup`) are inherently the jitteriest; the rampup + 50/20 iterations damp most of it, but treat those cells to ~1 significant figure and cross-check with `--metric min` if in doubt. `sort`, `insert`, `update` are stable. Rankings are stable across runs even where exact values aren't.
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
