//
//  Firestore+Extension.swift
//  HealthJournal
//
//  Created by matt naples on 1/6/23.
//

import Foundation
import FirebaseFirestore
protocol FirebaseCollection{
    func document(documentPath: String) -> FirebaseDocument
}
extension CollectionReference: FirebaseCollection{
    func document(documentPath: String) -> FirebaseDocument {
        self.document(documentPath)
    }
}
extension DocumentReference: FirebaseDocument{
    func setData<T>(from: T, callback: ((Error?) -> Void)?) throws  where T : Encodable {
        try self.setData(from: from, completion: callback)
    }
    func delete(callback: ((Error?) -> Void)?){
        self.delete(completion: callback)
    }
    func getDocument<T>() async throws -> T? where T: Decodable{
        let doc = try await self.getDocument()
        guard doc.exists else {return nil}
        let item = try doc.data(as: T.self)
        return item
    }
    
    
}
protocol FirebaseDocument{
    func setData<T>(from: T, callback: ((Error?) -> Void)?) throws  where T : Encodable
    func delete(callback: ((Error?) -> Void)?)
    func addSnapshotListener(_ listener: @escaping (DocumentSnapshot?, Error?) -> Void) -> ListenerRegistration
    func getDocument<T>() async throws -> T? where T: Decodable
    var documentID: String {get}
}
typealias FireStoreMapper<DomainModel, FirestoreDocumentModel: Codable & Identifiable> = (DomainModel) -> FirestoreDocumentModel
