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
public protocol GenericFirestoreService{
    associatedtype T: Identifiable & Codable
    associatedtype Err: Error
    associatedtype Writer: FirestoreWriter
    func unsubscribe(_ subscriptionId: UUID)
    
    func save(_ items: [T])  throws
    
    
    func save(_ item: T)  throws

    
    func delete(_ item: T) throws
    
    func subscribe(to: @escaping QueryBuilder,onUpdate: @escaping (Result<[T], Error>) -> Void) -> UUID
    func subscribeToChanges(on queryBuilder: QueryBuilder,onUpdate: @escaping (Result<[(DocumentChangeType, T)], Error>) -> Void) -> UUID
    
}

public class GenericFirestoreServiceDefaultImplementation<T: Identifiable & Codable, Err: Error, Writer: FirestoreWriter>: GenericFirestoreService where T.ID == String, Writer.Item == T{
    public func unsubscribe(_ subscriptionId: UUID) {
        firestoreListener.unsubscribe(subscriptionId)
    }
    
    public func save(_ items: [T])  throws {
        for item in items{
            try  self.save(item)
        }
    }
    
    public func save(_ item: T)  throws {
        try  firestoreDataWriter.save(item)
    }
    var errorHandler: (Error) -> Err

    public init(collection: CollectionReference, writer: Writer, errorHandler: @escaping (Error) -> Err){
        self.firestoreListener = FirestoreDataListener(collection: collection)
        self.firestoreDataWriter = writer
        self.errorHandler = errorHandler
    }
    public var firestoreListener: FirestoreDataListener<T>
    public var firestoreDataWriter: Writer
    
    public func delete(_ item: T) throws {
       try firestoreDataWriter.delete( item)
    }
    
    public func subscribe(to: @escaping QueryBuilder,onUpdate: @escaping (Result<[T], Error>) -> Void) -> UUID {
        let subscriptionId =  firestoreListener.subscribe(to: to) { [unowned self] result in
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
    public func subscribeToChanges(on queryBuilder: QueryBuilder,onUpdate: @escaping (Result<[(DocumentChangeType, T)], Error>) -> Void) -> UUID {
        let subscriptionId =  firestoreListener.subscribeToChanges(on: queryBuilder){ [weak self] result in
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


public class GenericFirestoreDocumentService<T: Codable, Err: Error> {
    public func unsubscribe(_ subscriptionId: UUID) {
        firestoreListener.unsubscribe(subscriptionId)
    }
    
    public func save(_ item: T)  throws {
        try  firestoreDataWriter.save(item)
    }
    var errorHandler: (Error) -> Err
    public init(documentReference: DocumentReference, errorHandler: @escaping (Error) -> Err){
        self.firestoreListener = FirestoreDocumentListener<T>(document: documentReference)
        self.firestoreDataWriter = FirestoreDocumentWriter<T,T>(document: documentReference)
        self.errorHandler = errorHandler
    }
    public var firestoreListener: FirestoreDocumentListener<T>
    public var firestoreDataWriter: FirestoreDocumentWriter<T,T>
    
    public func delete() throws {
       try firestoreDataWriter.delete()
    }
   
    public func subscribe(onUpdate: @escaping (Result<T?, Error>) -> Void) -> UUID {
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
    
    public func getDocument() async throws -> T?{
        try await self.firestoreListener.getDocument()
    }
}


