//
//  File.swift
//  
//
//  Created by matt naples on 9/8/23.
//

import Foundation
import FirebaseFirestore
public class FirebaseRecentItemService<T: Codable>{
    let dataLoader: FirestoreDataLoader<T>
    var collection: CollectionReference
    var dateFieldName: String
    public init(collection: CollectionReference, dateFieldName: String){
        self.dataLoader = FirestoreDataLoader(query: collection)
        self.dateFieldName = dateFieldName
        self.collection = collection
    }
    public func getItems(onOrAfter date: Date) async throws -> [T]{
        dataLoader.query = collection.whereFieldIsOnOrAfter(dateFieldName, date: date)
        return try await dataLoader.loadData(source: .default)
    }
    public func getItems(onDay: Date) async throws -> [T]{
        
        dataLoader.query = collection.whereField(dateFieldName, isDateInToday: onDay)
        return try await dataLoader.loadData(source: .default)
    }
    public func getItems(onDay: Date, completion: @escaping (Result<[T],Error>) -> Void){
        dataLoader.query = collection.whereField(dateFieldName, isDateInToday: onDay)
        
        dataLoader.loadData(source: .default, completion: completion)
    }
}
