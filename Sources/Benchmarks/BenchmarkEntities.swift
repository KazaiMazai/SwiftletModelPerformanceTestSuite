//
//  BenchmarkEntities.swift
//  SwiftletModelPerformanceTestSuite
//
//  SwiftletModel benchmark entities (indexed + unindexed) and in-memory store
//  builders for all three engines. SwiftData/Realm reuse the app's existing
//  SwiftUser / RealmUser models via @testable import.
//

import Foundation
import SwiftletModel
import SwiftData
import RealmSwift

// MARK: - SwiftletModel entities

// Each query type uses exactly one index (see SwiftletModel's QueryFilter:
// `==` → hash index; `!=` / `>` / sort → comparable BTree index). To measure
// each in isolation — and to make indexed *writes* reflect the cost of a single
// index rather than four — the indexed entity is split into four single-index
// variants instead of one entity carrying all four. All disable the implicit
// `updatedAt` metadata index (see PlainUser) so writes reflect only their one
// declared index.

/// Hash index on `age` — isolates equality·int (the O(1) hash-lookup path).
@EntityModel
struct IntHashUser {
    @HashIndex<Self>(\.age) var ageHashIndex
    let id: UUID
    var firstName: String
    var surname: String
    var age: Int
    init(id: UUID, firstName: String, surname: String, age: Int) {
        self.id = id; self.firstName = firstName; self.surname = surname; self.age = age
    }
    func saveMetadata(to context: inout Context) throws {}
    func deleteMetadata(from context: inout Context) throws {}
}

/// Comparable BTree index on `age` — isolates notEqual·int, comparison·int, sort·int.
@EntityModel
struct IntSortUser {
    @Index<Self>(\.age) var ageSortIndex
    let id: UUID
    var firstName: String
    var surname: String
    var age: Int
    init(id: UUID, firstName: String, surname: String, age: Int) {
        self.id = id; self.firstName = firstName; self.surname = surname; self.age = age
    }
    func saveMetadata(to context: inout Context) throws {}
    func deleteMetadata(from context: inout Context) throws {}
}

/// Hash index on `firstName` — isolates equality·string.
@EntityModel
struct StringHashUser {
    @HashIndex<Self>(\.firstName) var firstNameHashIndex
    let id: UUID
    var firstName: String
    var surname: String
    var age: Int
    init(id: UUID, firstName: String, surname: String, age: Int) {
        self.id = id; self.firstName = firstName; self.surname = surname; self.age = age
    }
    func saveMetadata(to context: inout Context) throws {}
    func deleteMetadata(from context: inout Context) throws {}
}

/// Comparable BTree index on `firstName` — isolates notEqual·string, comparison·string, sort·string.
@EntityModel
struct StringSortUser {
    @Index<Self>(\.firstName) var firstNameSortIndex
    let id: UUID
    var firstName: String
    var surname: String
    var age: Int
    init(id: UUID, firstName: String, surname: String, age: Int) {
        self.id = id; self.firstName = firstName; self.surname = surname; self.age = age
    }
    func saveMetadata(to context: inout Context) throws {}
    func deleteMetadata(from context: inout Context) throws {}
}

/// No indexes: every query is a full linear scan.
@EntityModel
struct PlainUser {
    let id: UUID
    var firstName: String
    var surname: String
    var age: Int

    init(id: UUID, firstName: String, surname: String, age: Int) {
        self.id = id
        self.firstName = firstName
        self.surname = surname
        self.age = age
    }

    // A *truly* index-free baseline. By default `@EntityModel` maintains an
    // implicit `updatedAt` metadata index on every save/delete — and since
    // `Date` is both Hashable and Comparable, that's a hash index *and* a
    // comparable BTree index updated per write. The benchmark never reads
    // `updatedAt`, so these no-ops remove that hidden index maintenance and make
    // the unindexed write numbers honest (zero indexes, pure scan store).
    func saveMetadata(to context: inout Context) throws {}
    func deleteMetadata(from context: inout Context) throws {}
}

/// SwiftletModel benchmark entities that can be built from a `UserRecord` or
/// from explicit fields (so write tests can prepare mutated copies generically).
protocol BenchmarkUser: EntityModelProtocol {
    init(record: UserRecord)
    init(id: UUID, firstName: String, surname: String, age: Int)
}

extension IntHashUser: BenchmarkUser {
    init(record: UserRecord) {
        self.init(id: record.id, firstName: record.firstName, surname: record.surname, age: record.age)
    }
}
extension IntSortUser: BenchmarkUser {
    init(record: UserRecord) {
        self.init(id: record.id, firstName: record.firstName, surname: record.surname, age: record.age)
    }
}
extension StringHashUser: BenchmarkUser {
    init(record: UserRecord) {
        self.init(id: record.id, firstName: record.firstName, surname: record.surname, age: record.age)
    }
}
extension StringSortUser: BenchmarkUser {
    init(record: UserRecord) {
        self.init(id: record.id, firstName: record.firstName, surname: record.surname, age: record.age)
    }
}

extension PlainUser: BenchmarkUser {
    init(record: UserRecord) {
        self.init(id: record.id, firstName: record.firstName, surname: record.surname, age: record.age)
    }
}

// MARK: - Indexed SwiftData / Realm entities
//
// Neither Realm nor SwiftData lets you pick an index *type* (Realm exposes one
// general index per field; SwiftData compiles `#Index` to a SQLite B-tree), so
// there's no hash-vs-comparable split to make. But to match the SwiftletModel
// isolation — one index per measurement, not two unrelated ones — each engine
// gets two single-field-indexed entities: one on `age` (serves the int reads)
// and one on `firstName` (serves the string reads and the writes, since the
// update mutates `firstName` and so churns that index).

/// SwiftData model with a single B-tree index on `age`.
@Model
final class SwiftUserAgeIndexed {
    #Index<SwiftUserAgeIndexed>([\.age])
    @Attribute(.unique) var id: UUID
    var firstName: String
    var surname: String
    var age: Int
    init(firstName: String, surname: String, age: Int) {
        self.id = UUID(); self.firstName = firstName; self.surname = surname; self.age = age
    }
}

/// SwiftData model with a single B-tree index on `firstName`.
@Model
final class SwiftUserNameIndexed {
    #Index<SwiftUserNameIndexed>([\.firstName])
    @Attribute(.unique) var id: UUID
    var firstName: String
    var surname: String
    var age: Int
    init(firstName: String, surname: String, age: Int) {
        self.id = UUID(); self.firstName = firstName; self.surname = surname; self.age = age
    }
}

/// Realm object with a single general index on `age` (primary-key `id` is auto-indexed).
final class RealmUserAgeIndexed: Object {
    @Persisted(primaryKey: true) var id: UUID
    @Persisted var firstName: String
    @Persisted var surname: String
    @Persisted(indexed: true) var age: Int
    convenience init(firstName: String, surname: String, age: Int) {
        self.init(); self.id = UUID(); self.firstName = firstName; self.surname = surname; self.age = age
    }
}

/// Realm object with a single general index on `firstName`.
final class RealmUserNameIndexed: Object {
    @Persisted(primaryKey: true) var id: UUID
    @Persisted(indexed: true) var firstName: String
    @Persisted var surname: String
    @Persisted var age: Int
    convenience init(firstName: String, surname: String, age: Int) {
        self.init(); self.id = UUID(); self.firstName = firstName; self.surname = surname; self.age = age
    }
}

// MARK: - In-memory store builders

enum Stores {

    // SwiftletModel — Context is in-memory by nature. One generic builder loads
    // any benchmark entity (the per-query single-index variants or PlainUser).

    static func context<U: BenchmarkUser>(_ type: U.Type, _ records: [UserRecord]) -> Context {
        var context = Context()
        for record in records {
            try! U(record: record).save(to: &context, options: .default)
        }
        return context
    }

    static func plainContext(_ records: [UserRecord]) -> Context {
        context(PlainUser.self, records)
    }

    // SwiftData — isStoredInMemoryOnly.

    static func emptySwiftDataContext() -> ModelContext {
        let configuration = ModelConfiguration(for: SwiftUser.self, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: SwiftUser.self, configurations: configuration)
        return ModelContext(container)
    }

    static func swiftDataContext(_ records: [UserRecord]) -> ModelContext {
        let context = emptySwiftDataContext()
        for record in records {
            context.insert(SwiftUser(firstName: record.firstName, surname: record.surname, age: record.age))
        }
        try! context.save()
        return context
    }

    // Realm — a fresh in-memory identifier per store keeps suites isolated.

    static func emptyRealm() -> Realm {
        let configuration = Realm.Configuration(inMemoryIdentifier: "bench-\(UUID().uuidString)")
        return try! Realm(configuration: configuration)
    }

    static func realm(_ records: [UserRecord]) -> Realm {
        let realm = emptyRealm()
        try! realm.write {
            for record in records {
                realm.add(RealmUser(firstName: record.firstName, surname: record.surname, age: record.age))
            }
        }
        return realm
    }

    // Indexed SwiftData / Realm variants — one entity per indexed field.

    static func emptySwiftDataContext<T: PersistentModel>(_ type: T.Type) -> ModelContext {
        let configuration = ModelConfiguration(for: T.self, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: T.self, configurations: configuration)
        return ModelContext(container)
    }

    static func ageIndexedSwiftDataContext(_ records: [UserRecord]) -> ModelContext {
        let context = emptySwiftDataContext(SwiftUserAgeIndexed.self)
        for r in records { context.insert(SwiftUserAgeIndexed(firstName: r.firstName, surname: r.surname, age: r.age)) }
        try! context.save()
        return context
    }

    static func emptyNameIndexedSwiftDataContext() -> ModelContext {
        emptySwiftDataContext(SwiftUserNameIndexed.self)
    }

    static func nameIndexedSwiftDataContext(_ records: [UserRecord]) -> ModelContext {
        let context = emptyNameIndexedSwiftDataContext()
        for r in records { context.insert(SwiftUserNameIndexed(firstName: r.firstName, surname: r.surname, age: r.age)) }
        try! context.save()
        return context
    }

    static func ageIndexedRealm(_ records: [UserRecord]) -> Realm {
        let realm = emptyRealm()
        try! realm.write {
            for r in records { realm.add(RealmUserAgeIndexed(firstName: r.firstName, surname: r.surname, age: r.age)) }
        }
        return realm
    }

    static func nameIndexedRealm(_ records: [UserRecord]) -> Realm {
        let realm = emptyRealm()
        try! realm.write {
            for r in records { realm.add(RealmUserNameIndexed(firstName: r.firstName, surname: r.surname, age: r.age)) }
        }
        return realm
    }
}
