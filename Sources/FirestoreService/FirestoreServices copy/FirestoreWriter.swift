//
//  FirestoreWriter.swift
//  HealthJournal
//
//  Created by matt naples on 2/24/23.
//

import Foundation
public protocol FirestoreWriter{
    associatedtype Item
    func save(_ item: Item)  throws
    func delete(_ item: Item) throws
}
