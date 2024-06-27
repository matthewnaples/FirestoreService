//
//  FirestoreWriter.swift
//  HealthJournal
//
//  Created by matt naples on 2/24/23.
//

import Foundation
public protocol FirestoreWriter{
    associatedtype Item
    func save(_ item: Item, errorCallback: ((Error?) -> Void)?)  throws
    func delete(_ item: Item, errorCallback: ((Error?) -> Void)?) throws
}
