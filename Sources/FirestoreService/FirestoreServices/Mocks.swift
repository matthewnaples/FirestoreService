//
//  Mocks.swift
//  FirestoreService
//
//  Created by matt naples on 1/16/25.
//

import Foundation
import Combine


protocol CollectionKnowledgable{
   static var collection: FirestoreCollection {get}
}
//in service module
protocol MockService{
    func subscribe(onUpdate: @escaping (Result<[MockModel], Error>) -> Void) -> UUID
    func unsubscribe(_ token: UUID)
}

//in application module
extension FirestoreSubscriptionListener: MockService{
}
extension FirestoreSubscriptionListener{
   func subscribe<Item>(onUpdate: @escaping (Result<[Item], any Error>) -> Void) -> UUID where Item : Codable & CollectionKnowledgable {
       self.subscribe(query: Item.collection, onUpdate: onUpdate)
   }
}


// MARK: - Mock Collection & Query
struct MockModel: Codable, Equatable {
   let id: String
   let value: Int
}
extension MockModel: CollectionKnowledgable{
    static var collection: FirestoreCollection { MockFirestoreCollection(mockQuery: .shared) }

}
class MockFirestoreCollection: FirestoreCollection {
   func snapshotPublisher() -> AnyPublisher<FirestoreQuerySnapshot, Error> {
       mockQuery.snapshotPublisher()
   }
   
   private let mockQuery: MockFirestoreQuery

   init(mockQuery: MockFirestoreQuery) {
       self.mockQuery = mockQuery
   }

   func asQuery() -> FirestoreQuery {
       // Return the mock query
       return mockQuery
   }
}

class MockFirestoreQuery: FirestoreQuery {
   static let shared = MockFirestoreQuery()
   private let subject = PassthroughSubject<FirestoreQuerySnapshot, Error>()

   /// Returns a publisher for FirestoreQuerySnapshot
   func snapshotPublisher() -> AnyPublisher<FirestoreQuerySnapshot, Error> {
       subject.eraseToAnyPublisher()
   }

   // Test helpers to send snapshots or errors
   func send(snapshot: FirestoreQuerySnapshot) {
       subject.send(snapshot)
   }

   func sendError(_ error: Error) {
       subject.send(completion: .failure(error))
   }
}

// MARK: - Mock Snapshot & Document

class MockQuerySnapshot: FirestoreQuerySnapshot {
   let allDocuments: [FirestoreDocumentSnapshot]

   init(documents: [FirestoreDocumentSnapshot]) {
       self.allDocuments = documents
   }
}

class MockDocumentSnapshot: FirestoreDocumentSnapshot {
   func data<T>(as type: T.Type) throws -> T where T : Decodable {
       try JSONDecoder().decode(T.self, from: mockData)
       
   }
   
   private let mockData: Data

   init(data: MockModel) {
       // Use JSONEncoder to encode the instance into Data
       let encoder = JSONEncoder()
       let data = try! encoder.encode(data)
       mockData = data
   }

   func data() throws -> [String : Any] {
       let json = try JSONSerialization.jsonObject(with: mockData, options: []) as! [String : Any]
       return json
   }
}

