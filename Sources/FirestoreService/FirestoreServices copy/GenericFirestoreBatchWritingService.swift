//
//  GenericFirestoreBatchWritingService.swift
//  HealthJournal
//
//  Created by matt naples on 1/6/23.
//



import Foundation
import Firebase
//import TCTService

class GenericFirestoreBatchWritingService<T: Identifiable & Codable,U: Identifiable & Codable,V: Identifiable & Codable, Err: Error> where T.ID == String, U.ID == String,V.ID == String{
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

    init(query: Query, collectionToWriteTo: CollectionReference, errorHandler: @escaping (Error) -> Err){
        self.firestoreListener = FirestoreDataListener(query: query)
        self.firestoreDataWriter = FirestoreDataWriter<T,T>(collection: collectionToWriteTo)
        self.errorHandler = errorHandler
    }
    var firestoreListener: FirestoreDataListener<T>
    var firestoreDataWriter: FirestoreDataWriter<T,T>
    
    func delete(_ item: T) throws {
       try firestoreDataWriter.delete( item)
    }
    
    func subscribe(onUpdate: @escaping (Result<[T], Error>) -> Void) -> UUID {
        let subscriptionId =  firestoreListener.subscribe { [unowned self] result in
            switch result{
            case .success(let items):

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




