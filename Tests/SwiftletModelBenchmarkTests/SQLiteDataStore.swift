//
//  SQLiteDataStore.swift
//  RealmVsSwiftDataBenchmarks
//
//  Point-Free SQLiteData (GRDB + StructuredQueries) model and in-memory store.
//  `import SQLiteData` re-exports GRDB (DatabaseQueue) and the query DSL.
//

import Foundation
import SQLiteData

/// `id` is auto-detected as the primary key by @Table. UUID binds as TEXT.
@Table("sqliteUsers")
struct SQLiteUser {
    let id: UUID
    var firstName: String
    var surname: String
    var age: Int
}

enum SQLiteStore {

    private static let createTableSQL = """
        CREATE TABLE "sqliteUsers" (
          "id" TEXT PRIMARY KEY NOT NULL,
          "firstName" TEXT NOT NULL,
          "surname" TEXT NOT NULL,
          "age" INTEGER NOT NULL
        )
        """

    static func users(_ records: [UserRecord]) -> [SQLiteUser] {
        records.map { SQLiteUser(id: $0.id, firstName: $0.firstName, surname: $0.surname, age: $0.age) }
    }

    /// Fresh in-memory database with the table created (no rows).
    static func emptyQueue() -> DatabaseQueue {
        let queue = try! DatabaseQueue()
        try! queue.write { db in try db.execute(sql: createTableSQL) }
        return queue
    }

    /// In-memory database populated with the given records (single batch insert).
    static func populatedQueue(_ records: [UserRecord]) -> DatabaseQueue {
        let queue = emptyQueue()
        let rows = users(records)
        try! queue.write { db in try SQLiteUser.insert { rows }.execute(db) }
        return queue
    }
}
