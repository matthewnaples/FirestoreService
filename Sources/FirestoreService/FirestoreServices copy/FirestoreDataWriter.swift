//
//  FirestoreDataWriter.swift
//  HealthJournal
//
//  Created by matt naples on 2/23/23.
//

import Foundation
import FirebaseFirestore
//import FirebaseFirestoreSwift
public class FirestoreDataWriter<T, FirestoreDocumentModel: Codable & Identifiable>: FirestoreWriter where FirestoreDocumentModel.ID == String {
   
    
    var listenerRegistration: ListenerRegistration?
    public typealias Item = T
    let collection: FirebaseCollection
//    typealias ErrorMapper = ((Error) -> Err)
//    let errorMapper: ErrorMapper
    let mapper: FireStoreMapper<T, FirestoreDocumentModel>
    public init(collection: FirebaseCollection, mapper: @escaping FireStoreMapper<T, FirestoreDocumentModel>){
        self.collection = collection
//        self.errorMapper = errorMapper
        self.mapper = mapper
    }
    public init(collection: FirebaseCollection) where T == FirestoreDocumentModel{
        self.collection = collection
        self.mapper = {return $0}
    }
    public func save(_ item: T) throws{
        let firItem = mapper(item)

        do{
            try collection.document(documentPath: firItem.id).setData(from: firItem){ error in
            if let error = error{
                
                print("---- error ----")
                print(type(of: error))
                print(error.localizedDescription)
                print("---- end error ----")
            }
            print("callback from update doc")
        }
        } catch{
            throw DSError.GeneralError("could not save item : \(firItem.id)", error)
        }
        print("\(firItem.id) has been updated with callback")
    }
    public func delete(_ item: T) throws{
        let firItem = mapper(item)
        collection.document(documentPath: firItem.id).delete{ error in
            if let error = error{
                
                print("---- error ----")
                print(type(of: error))
                print(error.localizedDescription)
                print("---- end error ----")
            }
            print("callback from update doc")
        }
        print("\( firItem.id) has been updated with callback")
    }
    public func unsubscribe(){
        self.listenerRegistration = nil
    }
}
