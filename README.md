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

- **SwiftletModel** — `indexed` (`@Index`/`@HashIndex`) and `unindexed` (full scan). Each query runs against an entity carrying *only* the index it uses, so each index is measured alone ([Index isolation](#index-isolation)); both also disable the implicit `updatedAt` metadata index.
- **Realm / SwiftData** — `default` and `indexed` (`@Persisted(indexed:)` / `#Index`), likewise split into single-field-indexed entities.
- **SQLiteData / GRDB** — `default` (no secondary index).

Each case runs a short **rampup** (discarded warmup iterations to reach steady state — warm caches, lazy init, SQLite prepared-statement compilation) and then times a fixed number of iterations: **50 for reads, 20 for writes** (reads are cheap to repeat; writes rebuild a fresh store every iteration). It's a manual warmup+timed loop with a monotonic clock — the suite is a plain executable (no XCTest, no assertions), just a registry of cases the runner expands over each size, appending a row per case to `BenchmarkResults/results.csv` (avg / min / max / stddev in ms).

A second, separate benchmark — [**Relational retrieval (Northwind)**](#relational-retrieval-northwind) — measures graph traversal across related entities (SwiftletModel's design focus) and writes to its own `BenchmarkResults/relational.csv`.

## Running

The suite is a plain SwiftPM **executable** (no XCTest), so it runs headless on macOS with one command — no app host, no simulator:

```bash
swift run -c release benchmarks                       # everything
swift run -c release benchmarks --suite SwiftletModel  # only matching suites
swift run -c release benchmarks --suite Northwind      # only the relational suites
swift run -c release benchmarks --size 1000            # only one dataset size
```

`--suite` matches against the suite class name (case-insensitive), so `--suite IndexedWrite`, `--suite Realm`, `--suite GRDBRead`, etc. all work.

> **Always use `-c release`.** A debug build compiles the Swift layers (SwiftletModel, RealmSwift, GRDB) unoptimized (`-Onone`), which penalizes them by 2–10× while leaving the C/C++ engines untouched — i.e. it produces *distorted*, not just slower, numbers.

Configure the dataset size(s) in `Sources/Benchmarks/BenchmarkCase.swift`:

```swift
static let sizes = [10, 100, 1_000, 10_000]   // one table is produced per size
```

Flat results are written to `BenchmarkResults/results.csv`; the relational suites write `relational.csv`. A *filtered* run rewrites only the file(s) its suites touch, so run without `--suite` for a complete `results.csv`.

## Printing the results

A dependency-free CLI renders the CSV as a comparison table:

```bash
swift run report                       # default CSV, avg ms, Int reads
swift run report path/to/results.csv   # explicit CSV path
swift run report --type string         # String variant for typed reads
swift run report --metric min          # min instead of avg
swift run report --by-engine           # per-engine scaling tables
swift run report --index-cost          # SwiftletModel write cost: hash vs comparable index
swift run report --relational          # Northwind relational.csv results
```

**Two layouts:**

- **Default** — one table *per size*: rows = operations, columns = engine configs (`idx` = indexed; a bare engine name is the no-secondary-index config). Highlights the fastest engine per row (bold green in a terminal).
- **`--by-engine`** — one table *per engine*: rows = item counts, columns = operations. Shows how each engine scales with dataset size.

Add **`--relational`** to either layout to render `BenchmarkResults/relational.csv` (the Northwind workloads, SwiftletModel / GRDB / SwiftData, size = order count) instead of the flat suite.

## Results

Apple Silicon, macOS, **Release**, in-memory, **rampup + 50 read / 20 write timed iterations**, single run, swept over **10 / 100 / 1,000 / 10,000** rows. Values are **avg ms** (lower is better); `Int` shown for typed reads. **Bold = fastest in row.**

Each query runs against an entity carrying **only the index it uses**, in isolation (see [Index isolation](#index-isolation)).

### Comparison at 10,000 rows

| Operation | SwiftletModel·idx | SwiftletModel | GRDB | SQLiteData | Realm | Realm·idx | SwiftData | SwiftData·idx |
|---|--:|--:|--:|--:|--:|--:|--:|--:|
| ID lookup | **0.00** | **0.00** | 0.03 | 0.04 | **0.00** | **0.00** | 0.06 | 0.05 |
| equal | **0.23** | 6.44 | 0.71 | 0.56 | 0.42 | 0.42 | 4.63 | 4.65 |
| not equal | **4.43** | 11.40 | 7.86 | 5.29 | 7.92 | 8.18 | 88.53 | 89.58 |
| compare | **2.20** | 8.74 | 4.03 | 2.76 | 4.29 | 3.91 | 40.96 | 43.56 |
| sort | 11.00 | 37.12 | 10.11 | **7.24** | 10.46 | 10.46 | 94.87 | 95.05 |
| insert | 56.65 | **7.04** | 47.73 | 59.47 | 48.70 | 58.78 | 476.35 | 507.36 |
| update | 121.70 | **7.17** | 102.50 | 152.05 | 7.48 | 15.72 | 369.03 | 367.19 |

> SwiftletModel·idx `insert`/`update` show the **comparable (BTree) index** variant — its closest analog to the single B-tree index Realm/SwiftData maintain. SwiftletModel can also use a cheaper hash index; both are broken out in [Index maintenance cost](#index-maintenance-cost) below.

### Scaling per engine (`--by-engine`)

`swift run report --by-engine` prints one of these per engine — rows are item counts, columns are operations — so you can read each engine's scaling curve. (avg ms, Int reads)

**SwiftletModel · indexed** — point reads stay flat; indexed writes scale *super*-linearly (index upkeep; `insert`/`update` shown for the comparable index):

| rows | ID lookup | equal | not equal | compare | sort | insert | update |
|--:|--:|--:|--:|--:|--:|--:|--:|
| 10 | 0.00 | 0.00 | 0.02 | 0.01 | 0.02 | 0.04 | 0.05 |
| 100 | 0.00 | 0.00 | 0.08 | 0.04 | 0.14 | 0.42 | 0.58 |
| 1,000 | 0.00 | 0.02 | 0.49 | 0.25 | 1.15 | 5.05 | 7.48 |
| 10,000 | 0.00 | 0.23 | 4.43 | 2.20 | 11.00 | 56.65 | 121.70 |

**SwiftletModel · unindexed** — no index, so even `equal`/`compare` scale ~linearly, but **writes are the fastest of any engine** (a pure keyed store, zero index maintenance):

| rows | ID lookup | equal | not equal | compare | sort | insert | update |
|--:|--:|--:|--:|--:|--:|--:|--:|
| 10 | 0.00 | 0.01 | 0.01 | 0.01 | 0.02 | 0.01 | 0.01 |
| 100 | 0.00 | 0.07 | 0.12 | 0.09 | 0.37 | 0.07 | 0.07 |
| 1,000 | 0.00 | 0.64 | 1.19 | 0.85 | 4.45 | 0.71 | 0.66 |
| 10,000 | 0.00 | 6.44 | 11.40 | 8.74 | 37.12 | 7.04 | 7.17 |

**GRDB · default**

| rows | ID lookup | equal | not equal | compare | sort | insert | update |
|--:|--:|--:|--:|--:|--:|--:|--:|
| 10 | 0.03 | 0.02 | 0.03 | 0.04 | 0.03 | 0.08 | 0.09 |
| 100 | 0.06 | 0.03 | 0.10 | 0.06 | 0.12 | 0.48 | 0.97 |
| 1,000 | 0.03 | 0.09 | 0.81 | 0.43 | 0.99 | 5.11 | 8.95 |
| 10,000 | 0.03 | 0.71 | 7.86 | 4.03 | 10.11 | 47.73 | 102.50 |

**SQLiteData · default**

| rows | ID lookup | equal | not equal | compare | sort | insert | update |
|--:|--:|--:|--:|--:|--:|--:|--:|
| 10 | 0.04 | 0.03 | 0.03 | 0.03 | 0.03 | 0.08 | 0.16 |
| 100 | 0.04 | 0.03 | 0.08 | 0.05 | 0.09 | 0.60 | 1.51 |
| 1,000 | 0.04 | 0.08 | 0.57 | 0.30 | 0.74 | 5.84 | 14.92 |
| 10,000 | 0.04 | 0.56 | 5.29 | 2.76 | 7.24 | 59.47 | 152.05 |

**Realm · default** — `update` is the standout: ~7 ms at 10k while the SQL engines are 100–150 ms:

| rows | ID lookup | equal | not equal | compare | sort | insert | update |
|--:|--:|--:|--:|--:|--:|--:|--:|
| 10 | 0.00 | 0.01 | 0.02 | 0.02 | 0.01 | 0.13 | 0.12 |
| 100 | 0.00 | 0.01 | 0.08 | 0.04 | 0.10 | 0.77 | 0.18 |
| 1,000 | 0.00 | 0.05 | 0.79 | 0.37 | 1.00 | 4.96 | 0.82 |
| 10,000 | 0.00 | 0.42 | 7.92 | 4.29 | 10.46 | 48.70 | 7.48 |

**Realm · indexed** (single index on the written field)

| rows | ID lookup | equal | not equal | compare | sort | insert | update |
|--:|--:|--:|--:|--:|--:|--:|--:|
| 10 | 0.00 | 0.01 | 0.03 | 0.01 | 0.01 | 0.19 | 0.12 |
| 100 | 0.00 | 0.01 | 0.08 | 0.04 | 0.10 | 0.72 | 0.29 |
| 1,000 | 0.00 | 0.05 | 0.79 | 0.39 | 1.01 | 6.02 | 1.51 |
| 10,000 | 0.00 | 0.42 | 8.18 | 3.91 | 10.46 | 58.78 | 15.72 |

**SwiftData · default** — last on every read/insert; the gap widens with N (`not equal` ~89 ms at 10k):

| rows | ID lookup | equal | not equal | compare | sort | insert | update |
|--:|--:|--:|--:|--:|--:|--:|--:|
| 10 | 0.05 | 0.06 | 0.13 | 0.09 | 0.14 | 0.78 | 0.76 |
| 100 | 0.06 | 0.09 | 0.94 | 0.44 | 1.05 | 4.57 | 4.05 |
| 1,000 | 0.06 | 0.55 | 8.26 | 4.05 | 9.41 | 42.55 | 37.34 |
| 10,000 | 0.06 | 4.63 | 88.53 | 40.96 | 94.87 | 476.35 | 369.03 |

**SwiftData · indexed** (single index on the written field)

| rows | ID lookup | equal | not equal | compare | sort | insert | update |
|--:|--:|--:|--:|--:|--:|--:|--:|
| 10 | 0.06 | 0.05 | 0.13 | 0.09 | 0.14 | 0.83 | 0.62 |
| 100 | 0.06 | 0.09 | 0.97 | 0.46 | 1.02 | 4.67 | 3.73 |
| 1,000 | 0.06 | 0.54 | 8.68 | 4.26 | 9.23 | 43.81 | 36.67 |
| 10,000 | 0.05 | 4.65 | 89.58 | 43.56 | 95.05 | 507.36 | 367.19 |

### Index maintenance cost

`swift run report --index-cost` isolates how much one SwiftletModel index adds to writes, by kind (avg ms). A comparable BTree index costs **~2.5× (insert) / ~3.6× (update)** what a hash index does; `update` churns more than `insert` because the old key is removed and the new one inserted:

| rows | insert·hash | insert·cmp | update·hash | update·cmp |
|--:|--:|--:|--:|--:|
| 10 | 0.02 | 0.04 | 0.03 | 0.05 |
| 100 | 0.22 | 0.42 | 0.32 | 0.58 |
| 1,000 | 2.55 | 5.05 | 3.17 | 7.48 |
| 10,000 | 22.42 | 56.65 | 34.13 | 121.70 |

### Takeaways

- **SwiftletModel (indexed) wins every read except `sort`** — `ID lookup` (~0, O(1)), `equal` (0.23 ms at 10k vs SwiftData's 4.6 — ~20×), `not equal` (4.4 vs SQLite's 5.3), and `compare` (2.2 vs 2.8). Its in-memory keyed store + indexes are unbeatable for *finding* rows.
- **SwiftletModel (unindexed) wins every write** — at 10k, insert 7.0 ms (vs GRDB's 48 — ~7×) and update 7.2 ms (just past Realm's 7.5, ~14× faster than GRDB). With no indexes it's a pure keyed store doing zero index maintenance, so writes are essentially the cost of inserting into a dictionary.
- **`sort` goes to SQLiteData** (7.2 ms at 10k) — SQLite's native C sort is the fastest in-RAM, with GRDB / Realm / indexed SwiftletModel clustered ~10–11 ms behind.
- **Realm owns mutable `update` among stores that keep their indexes** — 7.5 ms at 10k (in-place mutation of live objects), with unindexed SwiftletModel a hair faster but index-free.
- **The SwiftletModel read/write trade-off is real but no longer lopsided.** Indexed: wins reads, but one comparable index costs 57 ms insert / 122 ms update at 10k (index upkeep is super-linear). Unindexed: wins writes, but `equal`/`compare` become linear scans. **You pick one config per entity** — there's no setting that wins both.
- **Index *kind* matters for write cost.** A hash index (equality-only) is ~2.5–3.6× cheaper to maintain than a comparable BTree index — so if you only ever do equality lookups, `@HashIndex` keeps writes much closer to the unindexed baseline (insert 22 vs 57 ms, update 34 vs 122 ms at 10k). SwiftletModel is the only engine here that lets you make that choice (Realm/SwiftData expose a single index type).
- **SwiftData is last on every read and insert, by ~8–10×** (`not equal` 89 ms, insert 476 ms at 10k). It runs the *same* `:memory:` SQLite as SQLiteData/GRDB — both far faster — so the cost is its object-materialization layer, not the database.
- **Scaling shapes:** `ID lookup` flat (O(1)); indexed `equal` scales gently while *unindexed* `equal` is ~linear; unindexed writes are ~linear and cheap; indexed writes are super-linear.

### Index isolation

Each query is benchmarked against an entity carrying **only the one index that query uses**, not a bundle of unrelated indexes:

- **SwiftletModel** maps each operator to a specific index — `==` → hash index, `!=`/`>`/sort → comparable BTree index — so the indexed reads use one matching single-index entity each, and the indexed *writes* are measured per index kind (hash and comparable separately; see [Index maintenance cost](#index-maintenance-cost)).
- **Realm / SwiftData** don't expose an index *type* (Realm has one general index; SwiftData compiles `#Index` to a SQLite BTree), so there's no hash/comparable split — but they're still given two single-field-indexed entities (one on the queried int field, one on the written string field) so each measurement carries one index, not two.
- This matters for *writes* (each engine's indexed-write number reflects **one** index); for *reads* it doesn't move the numbers — a query resolves only its own index by name regardless of how many others exist (verified: isolated indexed reads matched the bundled-index reads exactly).

> **Note on "unindexed".** `@EntityModel` maintains an implicit `updatedAt` metadata index (a hash *and* a comparable BTree index, since `Date` is both) on every save. The benchmark entities override `saveMetadata`/`deleteMetadata` to no-ops so the unindexed config is genuinely index-free. Without this, write numbers are inflated several-fold (unindexed insert/update were ~61/106 ms instead of ~7 ms). If your real entities use `updatedAt`, add that cost back.

## Relational retrieval (Northwind)

The flat suite above measures single-table primitives. A second, **separate** benchmark targets **relational retrieval** — SwiftletModel's design focus — on synthetic data shaped like the classic **Northwind** schema (Categories, Suppliers, Shippers, Employees, Customers, Products, Orders, Order Details). Only the three engines with real relationship support are compared: **SwiftletModel** (normalized `@Relationship` graph), **GRDB** (hand-written, FK-indexed SQL JOINs — SQLite's best case), and **SwiftData** (object-graph faulting). Here `size` is the **order count**; line items fan out ~4×. Results go to their own file, `BenchmarkResults/relational.csv`, so running one suite never clobbers the other.

Four workloads — modeled on Northwind's own views — span the spectrum from navigational to bulk:

| Workload | Shape | What it does |
|---|---|---|
| `productsByCat` | few-side fan-out | non-discontinued products grouped under their 8 categories |
| `orderDetailsExt` | few-side fan-out | each line item joined to its product (extended price) |
| `orderInvoice (nav)` | **navigational** | for ~200 sampled orders, traverse each order's full graph (customer + employee + shipper + line items + products) into that order's invoice rows |
| `invoices (bulk)` | **bulk wide join** | flatten *every* order into the full 6-table denormalized invoice |

```bash
swift run -c release benchmarks --suite Northwind   # writes BenchmarkResults/relational.csv
swift run report --relational                 # per-size tables (add --by-engine for scaling)
```

### Results (avg ms, lower is better; **bold = fastest**)

| Workload | 1,000 · Swiftlet | 1,000 · GRDB | 1,000 · SwiftData | 10,000 · Swiftlet | 10,000 · GRDB | 10,000 · SwiftData |
|---|--:|--:|--:|--:|--:|--:|
| productsByCat | **0.06** | 0.07 | 2.39 | **0.06** | 0.06 | 4.09 |
| orderDetailsExt | **1.98** | 3.09 | 68.05 | **18.38** | 31.22 | 673.54 |
| orderInvoice (nav) | **5.99** | 10.73 | 157.75 | **6.36** | 11.14 | 225.40 |
| invoices (bulk) | 30.73 | **6.22** | 289.09 | 321.50 | **64.07** | 2920.70 |

### Takeaways

- **Navigational traversal is SwiftletModel's home turf.** `orderInvoice` — fetch an order by id, then hop its graph — is **~1.7× faster than GRDB** and **~35× faster than SwiftData** at every size. An in-memory index lookup plus direct pointer-following beats re-running a 5-table join (+ statement step) per order, and obliterates SwiftData's faulting.
- **Traversal direction matters enormously for fan-out reads.** Traversing from the *few* side (`Category → its products`, `Product → its line items`) resolves each of the 8 categories / 77 products **once** rather than re-resolving them per row. That alone turned an earlier ~3.6× *loss* into a ~1.6× *win* on `orderDetailsExt` (1.98 vs GRDB's 3.09 ms at 1k). Drive `.with` from the side with fewer entities.
- **Bulk denormalized dumps still go to SQL.** `invoices` — materialize every row of the full 6-table join — is GRDB's by ~5×. Producing one giant flattened table is exactly what SQLite's join engine is built for; SwiftletModel pays a per-entity materialization cost across the whole fan-out.
- **SwiftData is last on every relational workload** (25–45× behind), dominated by object faulting as the graph is walked.

**Rule of thumb:** if you need to *traverse the graph and assemble a result* (navigational reads, point lookups, moderate fan-out from the few side), SwiftletModel wins. If you need to *dump a huge fully-denormalized table*, reach for SQL.

## Methodology & caveats

- **Release only** (see above). Cross-module optimization isn't enabled because it conflicts with the testability needed by the test target; `-O` + whole-module is the representative max.
- **In-memory.** SwiftData/SQLite indexes mainly optimize disk I/O, so on disk the comparison would shift.
- **Noise.** The sub-millisecond reads (`equal`/`compare`/`ID lookup`) are inherently the jitteriest; the rampup + 50/20 iterations damp most of it, but treat those cells to ~1 significant figure and cross-check with `--metric min` if in doubt. `sort`, `insert`, `update` are stable. Rankings are stable across runs even where exact values aren't.
- **Result semantics differ:** SwiftletModel/SQLiteData/GRDB/SwiftData return value copies; Realm returns lazy live objects (cheap to fetch, cost deferred to access).
- This is a **micro-benchmark of a synthetic workload** — use it to understand the engines' shapes, not as a single verdict.

## Project layout

```
Package.swift                    # two executables: `benchmarks` and `report`
Sources/
  Report/                        # CSV → table CLI (the `report` command)
  Benchmarks/                    # the benchmark suite (the `benchmarks` command, no XCTest)
    Runner.swift                 # @main: suite registry + CLI arg filtering
    BenchmarkCase.swift          # base class, sizes, metadata, measure helpers
    BenchmarkDataset.swift       # seeded dataset + query targets
    BenchmarkEntities.swift      # SwiftletModel entities + in-memory store builders
    BenchmarkResultsWriter.swift # appends results to results.csv / relational.csv
    <Engine>ReadTests.swift / <Engine>WriteTests.swift
    Northwind/                   # relational suite: dataset + per-engine schemas + view workloads
    Support/                     # SwiftUser, RealmUser, name pools
```
