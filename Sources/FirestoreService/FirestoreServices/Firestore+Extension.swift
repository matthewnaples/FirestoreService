//
//  Firestore+Extension.swift
//  HealthJournal
//
//  Created by matt naples on 1/6/23.
//

import Foundation
import FirebaseFirestore
public protocol FirebaseCollection{
    func document(documentPath: String) -> FirebaseDocument
}
extension CollectionReference: FirebaseCollection{
    public func document(documentPath: String) -> FirebaseDocument {
        self.document(documentPath)
    }
}
extension DocumentReference: FirebaseDocument{
    
    public func setData<T>(from: T, callback: ((Error?) -> Void)?) throws  where T : Encodable {
        try self.setData(from: from, completion: callback)
    }
    public func delete(callback: ((Error?) -> Void)?){
        self.delete(completion: callback)
    }
    public func getDocument<T>() async throws -> T? where T: Decodable{
        let doc = try await self.getDocument()
        guard doc.exists else {return nil}
        let item = try doc.data(as: T.self)
        return item
    }
    
    public func getDocument<T>(source: FirestoreSource, completion: @escaping (Result<T?,Error>) -> Void)  where T: Decodable{
        self.getDocument(source: source) { maybeDoc, maybeErr in
            if let error = maybeErr{
                completion(.failure(error))
                return
            }
            do{
                 let item = try maybeDoc?.data(as: T.self)
                completion(.success(item))
                
            } catch{
                completion(.failure(error))
            }
        }
    }
}
public protocol FirebaseDocument{
    func setData<T>(from: T, callback: ((Error?) -> Void)?) throws  where T : Encodable
    func delete(callback: ((Error?) -> Void)?)
    func addSnapshotListener(_ listener: @escaping (DocumentSnapshot?, Error?) -> Void) -> ListenerRegistration
    func getDocument<T>() async throws -> T? where T: Decodable
    func getDocument<T>(source: FirestoreSource, completion:  @escaping (Result<T?,Error>) -> Void) where T: Decodable
    var documentID: String {get}
    
}
public typealias FireStoreMapper<DomainModel, FirestoreDocumentModel: Codable & Identifiable> = (DomainModel) -> FirestoreDocumentModel
