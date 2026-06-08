//
//  AppModels.swift
//  SwiftletModelPerformanceTestSuite
//
//  SwiftData / Realm "simple object" models, moved out of the old app target so
//  the benchmark stands alone. Only what the suite needs: a unique-indexed `id`
//  primary key plus firstName / surname / age.
//

import Foundation
import SwiftData
import RealmSwift

// SwiftletModel requires an entity's `ID` to be LosslessStringConvertible.
extension UUID: @retroactive LosslessStringConvertible {
    public init?(_ description: String) {
        self.init(uuidString: description)
    }
}

@Model
final class SwiftUser {
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

final class RealmUser: Object {
    @Persisted(primaryKey: true) var id: UUID
    @Persisted var firstName: String
    @Persisted var surname: String
    @Persisted var age: Int

    // Realm requires custom initializers to be `convenience`.
    convenience init(firstName: String, surname: String, age: Int) {
        self.init()
        self.id = UUID()
        self.firstName = firstName
        self.surname = surname
        self.age = age
    }
}
