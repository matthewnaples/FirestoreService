//
//  GenericFirestoreService.swift
//  HealthJournal
//
//  Created by matt naples on 12/15/22.
//


import Foundation
import Firebase

///creates an error that will be displayed when  no descriptive error case can be found.
//protocol GeneralApplicationError: Error{
//    associatedtype Err: Error
//    static func createGeneralError() -> Err
//}
class GenericFirestoreService<T: Identifiable & Codable, Err: Error, Writer: FirestoreWriter> where T.ID == String, Writer.Item == T{
    func unsubscribe(_ subscriptionId: UUID) {
        firestoreListener.unsubscribe(subscriptionId)
    }
    
    func save(_ items: [T])  throws {
        for item in items{
            try  self.save(item)
        }
    }
    
    func save(_ item: T)  throws {
        try  firestoreDataWriter.save(item)
    }
    var errorHandler: (Error) -> Err

    init(query: Query, writer: Writer, errorHandler: @escaping (Error) -> Err){
        self.firestoreListener = FirestoreDataListener(query: query)
        self.firestoreDataWriter = writer
        self.errorHandler = errorHandler
    }
    var firestoreListener: FirestoreDataListener<T>
    var firestoreDataWriter: Writer
    
    func delete(_ item: T) throws {
       try firestoreDataWriter.delete( item)
    }
    
    func subscribe(onUpdate: @escaping (Result<[T], Error>) -> Void) -> UUID {
        let subscriptionId =  firestoreListener.subscribe { [unowned self] result in
            switch result{
            case .success(let items):
                print("fetched \(items.count) items of type \(type(of: T.self))")
                onUpdate(.success(items))
            case .failure(let err):
//                guard let self = self else{
//                    return
//                }
                onUpdate(.failure(self.errorHandler(err)))
            }
        }
        return subscriptionId
    }
    func subscribeToChanges(onUpdate: @escaping (Result<[(DocumentChangeType, T)], Error>) -> Void) -> UUID {
        let subscriptionId =  firestoreListener.subscribeToChanges { [weak self] result in
            switch result{
            case .success(let items):
                
                onUpdate(.success(items.map{($0.0, $0.1)}))
            case .failure(let err):
                guard let self = self else{
                    return
                }
                onUpdate(.failure(self.errorHandler(err)))
            }
        }
        return subscriptionId
    }

}


class GenericFirestoreDocumentService<T: Codable, Err: Error> {
    func unsubscribe(_ subscriptionId: UUID) {
        firestoreListener.unsubscribe(subscriptionId)
    }
    
    func save(_ item: T)  throws {
        try  firestoreDataWriter.save(item)
    }
    var errorHandler: (Error) -> Err
    init(documentReference: DocumentReference, errorHandler: @escaping (Error) -> Err){
        self.firestoreListener = FirestoreDocumentListener<T>(document: documentReference)
        self.firestoreDataWriter = FirestoreDocumentWriter<T,T>(document: documentReference)
        self.errorHandler = errorHandler
    }
    var firestoreListener: FirestoreDocumentListener<T>
    var firestoreDataWriter: FirestoreDocumentWriter<T,T>
    
    func delete() throws {
       try firestoreDataWriter.delete()
    }
   
    func subscribe(onUpdate: @escaping (Result<T?, Error>) -> Void) -> UUID {
        let subscriptionId =  firestoreListener.subscribe { [weak self] result in
            switch result{
            case .success(let items):
                onUpdate(.success(items))
            case .failure(let err):
                guard let self = self else{
                    return
                }
                onUpdate(.failure(self.errorHandler(err)))
            }
        }
        return subscriptionId
    }
    
    func getDocument() async throws -> T?{
        try await self.firestoreListener.getDocument()
    }
}


