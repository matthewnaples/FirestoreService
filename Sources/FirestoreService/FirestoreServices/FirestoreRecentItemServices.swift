//
//  File.swift
//  
//
//  Created by matt naples on 9/8/23.
//

import Foundation
import FirebaseFirestore
public class FirebaseRecentItemService<T: Codable>{
    public let dataLoader: FirestoreDataLoader<T>
    var collection: CollectionReference
    var dateFieldName: String
    public init(collection: CollectionReference, dateFieldName: String){
        self.dataLoader = FirestoreDataLoader(collection: collection)
        self.dateFieldName = dateFieldName
        self.collection = collection
    }
    public func getItems(onOrAfter date: Date) async throws -> [T]{
        return try await dataLoader.loadData(source: .default, queryBuilder: { collection in
            collection.whereFieldIsOnOrAfter(dateFieldName, date: date)
        })
    }
    public func getItems(onDay: Date) async throws -> [T]{
        return try await dataLoader.loadData(source: .default, queryBuilder: {collection in
            collection.whereField(dateFieldName, isDateInToday: onDay)
        })
    }
    public func getItems(onDay: Date, completion: @escaping (Result<[T],Error>) -> Void){
        
        dataLoader.loadData(source: .default, queryBuilder: {
            $0.whereField(dateFieldName, isDateInToday: onDay)
        }, completion: completion)
    }
}
