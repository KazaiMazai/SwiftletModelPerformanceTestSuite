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

/// Fully indexed: a hash index (O(1) equality) and a comparable BTree index
/// (range / comparison / sort) on both the String and Int fields.
@EntityModel
struct IndexedUser {
    @HashIndex<Self>(\.firstName) var firstNameHashIndex
    @Index<Self>(\.firstName) var firstNameSortIndex
    @HashIndex<Self>(\.age) var ageHashIndex
    @Index<Self>(\.age) var ageSortIndex

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
}

extension IndexedUser {
    init(record: UserRecord) {
        self.init(id: record.id, firstName: record.firstName, surname: record.surname, age: record.age)
    }
}

extension PlainUser {
    init(record: UserRecord) {
        self.init(id: record.id, firstName: record.firstName, surname: record.surname, age: record.age)
    }
}

// MARK: - Indexed SwiftData / Realm entities

/// SwiftData model with single-column indexes on the queried fields (iOS 18+
/// `#Index` macro). Mirror of `SwiftUser` for the indexed comparison.
@Model
final class IndexedSwiftUser {
    #Index<IndexedSwiftUser>([\.firstName], [\.age])

    @Attribute(.unique) var id: UUID
    var firstName: String
    var surname: String
    var age: Int

    init(firstName: String, surname: String, age: Int) {
        self.id = UUID()
        self.firstName = firstName
        self.surname = surname
        self.age = age
    }
}

/// Realm object with indexed `firstName` and `age` (the primary-key `id` is
/// auto-indexed). Realm indexes accelerate equality/IN lookups.
final class IndexedRealmUser: Object {
    @Persisted(primaryKey: true) var id: UUID
    @Persisted(indexed: true) var firstName: String
    @Persisted var surname: String
    @Persisted(indexed: true) var age: Int

    convenience init(firstName: String, surname: String, age: Int) {
        self.init()
        self.id = UUID()
        self.firstName = firstName
        self.surname = surname
        self.age = age
    }
}

// MARK: - In-memory store builders

enum Stores {

    // SwiftletModel — Context is in-memory by nature.

    static func indexedContext(_ records: [UserRecord]) -> Context {
        var context = Context()
        for record in records {
            try! IndexedUser(record: record).save(to: &context)
        }
        return context
    }

    static func plainContext(_ records: [UserRecord]) -> Context {
        var context = Context()
        for record in records {
            try! PlainUser(record: record).save(to: &context)
        }
        return context
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

    // Indexed SwiftData / Realm variants.

    static func emptyIndexedSwiftDataContext() -> ModelContext {
        let configuration = ModelConfiguration(for: IndexedSwiftUser.self, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: IndexedSwiftUser.self, configurations: configuration)
        return ModelContext(container)
    }

    static func indexedSwiftDataContext(_ records: [UserRecord]) -> ModelContext {
        let context = emptyIndexedSwiftDataContext()
        for record in records {
            context.insert(IndexedSwiftUser(firstName: record.firstName, surname: record.surname, age: record.age))
        }
        try! context.save()
        return context
    }

    static func indexedRealm(_ records: [UserRecord]) -> Realm {
        let realm = emptyRealm()
        try! realm.write {
            for record in records {
                realm.add(IndexedRealmUser(firstName: record.firstName, surname: record.surname, age: record.age))
            }
        }
        return realm
    }
}
