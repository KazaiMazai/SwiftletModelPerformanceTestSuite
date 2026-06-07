//
//  GRDBStore.swift
//  RealmVsSwiftDataBenchmarks
//
//  Plain GRDB (no StructuredQueries layer) — its native query interface over an
//  in-memory DatabaseQueue. Contrast with SQLiteData, which wraps GRDB.
//

import Foundation
import GRDB

struct GRDBUser: Codable, FetchableRecord, PersistableRecord {
    var id: String
    var firstName: String
    var surname: String
    var age: Int

    static let databaseTableName = "grdbUsers"

    enum Columns {
        static let id = Column("id")
        static let firstName = Column("firstName")
        static let age = Column("age")
    }
}

enum GRDBStore {

    static func users(_ records: [UserRecord]) -> [GRDBUser] {
        records.map { GRDBUser(id: $0.id.uuidString, firstName: $0.firstName, surname: $0.surname, age: $0.age) }
    }

    static func emptyQueue() -> DatabaseQueue {
        let queue = try! DatabaseQueue()
        try! queue.write { db in
            try db.create(table: GRDBUser.databaseTableName) { t in
                t.primaryKey("id", .text)
                t.column("firstName", .text).notNull()
                t.column("surname", .text).notNull()
                t.column("age", .integer).notNull()
            }
        }
        return queue
    }

    static func populatedQueue(_ records: [UserRecord]) -> DatabaseQueue {
        let queue = emptyQueue()
        let rows = users(records)
        try! queue.write { db in
            for user in rows { try user.insert(db) }
        }
        return queue
    }
}
