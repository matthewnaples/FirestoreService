//
//  FirestoreBatchedWriter.swift
//  HealthJournal
//
//  Created by matt naples on 1/6/23.
//

import Foundation
import FirebaseFirestore
// This will write two objects to firestore in a batch. The second object is to be placed in a subcollection of the first.
class FirestoreBatchedWriter<Item: Codable & Identifiable, T: Codable & Identifiable, U: Codable & Identifiable>: FirestoreWriter where  Item.ID == String,T.ID == String, U.ID == String{
    func save(_ item: Item) throws {
        let (documentModel1, documentModel2) = itemMapper(item)
        try batchSave(item1: documentModel1, item2: documentModel2)
    }
    
    func delete(_ item: Item) throws {
        let (documentModel1, documentModel2) = itemMapper(item)
        
        try batchDelete(item1: documentModel1, item2: documentModel2)
    }
    

    init(collection1: CollectionReference, collection2: CollectionReference, itemMapper: @escaping (Item) -> (T,[U])){
        db = Firestore.firestore()
        self.collection1 = collection1
        self.collection2 = collection2
        self.itemMapper = itemMapper
    }
    let itemMapper: (Item) -> (T,[U])
    let db: Firestore
    let collection1: CollectionReference
    let collection2: CollectionReference

    
    ///saves item1 to collection2 and item2 to collection2
    func batchSave(item1: T, item2: [U]) throws{
        // Get new write batch
        let batch = db.batch()
        
        // Set the value of item1 in collection 1
        let item1DocRef = collection1.document(item1.id)
        try batch.setData(from: item1.self, forDocument: item1DocRef)
        
        // Set the values of item2 in collection 2
        for item in item2{
            let itemDocRef = collection2.document(item.id)
            try batch.setData(from: item.self, forDocument: itemDocRef)
        }

        // Commit the batch
        batch.commit(){err in
            print("\(err?.localizedDescription)")
            print("committed batch")
        }

    }
    
    ///saves item1 to collection2 and item2 to collection2
    func batchSave(item1: T, item2: [U]) async throws{
        // Get new write batch
        let batch = db.batch()

        // Set the value of item1 in collection 1
        let item1DocRef = collection1.document(item1.id)
        try batch.setData(from: item1.self, forDocument: item1DocRef)
        
        // Set the value of item2 in collection 2
        for item in item2{

        let itemDocRef = collection2.document(item.id)
        try batch.setData(from: item.self, forDocument: itemDocRef)

        }

        // Commit the batch
        try await batch.commit()
       

    }
    /// deletes item1 and item2 in a batch.
    func batchDelete(item1: T, item2: [U]) throws{
        // Get new write batch
        let batch = db.batch()
        // Set the value of item1 in collection 1
        let item1DocRef = collection1.document(item1.id)
        batch.deleteDocument(item1DocRef)
        
        // Set the value of item2 in collection 2
        for item in item2{
            let itemDocRef = collection2.document(item.id)
            batch.deleteDocument(itemDocRef)
        }
        batch.commit()
    }
    /// deletes item1 and item2 in a batch asynchronously
    func batchDeleteAsync(item1: T, item2: [U]) async throws{
        // Get new write batch
        let batch = db.batch()
        // Set the value of item1 in collection 1
        let item1DocRef = collection1.document(item1.id)
        batch.deleteDocument(item1DocRef)
        
        // Set the value of item2 in collection 2
        for item in item2{
            let itemDocRef = collection2.document(item.id)
            batch.deleteDocument(itemDocRef)
        }
        try await batch.commit()
    }
    
}
