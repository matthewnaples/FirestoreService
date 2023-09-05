//
//  FirestoreSingleDocumentService.swift
//  HealthJournal
//
//  Created by matt naples on 2/23/23.
//

import Foundation
import FirebaseFirestore

public class FirestoreDocumentListener<T: Codable>{

    let decodingProblemThreshold: Double = 0.5
    var document: FirebaseDocument
    var listenerRegistrations: [UUID: ListenerRegistration] =  [:]
//    let errorMapper: ErrorMapper
//    typealias ErrorMapper = ((Error) -> Err)

    public init(document: FirebaseDocument){
        self.document = document
        
    }
    func getDocument() async throws -> T?{
        try await document.getDocument()
    }
    func getDocument(source: FirestoreSource,completion: @escaping (Result<T?,Error>) -> Void){
        self.document.getDocument(source: source) { result in
            completion(result)
        }
    }
    func subscribe(_ onUpdate: @escaping (Result<T?,DSError>) -> Void) -> UUID {
        let listenerId = UUID()
        self.listenerRegistrations[listenerId] = getListener( handler: onUpdate)
        return listenerId
    }
    
    func unsubscribe(_ subscriptionId: UUID) {
        self.listenerRegistrations.removeValue(forKey: subscriptionId)
    }
    
    private func getListener(handler:  @escaping ((Result<T?,DSError>)->Void)) -> ListenerRegistration{
        let registration = document.addSnapshotListener { snapshot, anError in
            
            if let err = anError {
                handler(.failure(DSError.GeneralError("An error occurred while fetching data from the network", err)))
                return
            }
            
            guard let doc: DocumentSnapshot = snapshot else{
                handler(.failure(DSError.GeneralError("the snapshot was empty", nil)))
                return
            }
            
//             we should definitely not throw an error here... pass an empty array dummy
//            guard !documents.isEmpty else{
//                result = .failure(DSError.NotFound("no documents exist in the given collection"))
//                handler(result)
//                return
//            }
            
                do{
                    print(type(of: self))
                    guard doc.exists else{
                        handler(.success(nil))
                        return
                    }
                    let obj = try! doc.data(as: T.self)
                    handler(.success(obj))
                    return
                }
                catch{
                    handler(.failure(.CouldNotDecode("The document could not be decoded.", [CodingProblem(problemDocumentSnapshot: doc, error: error)])))
                    return
                }
            
        }
        
        return registration
    }

    typealias Item = T
}

typealias FireStoreDocumentMapper<DomainModel, FirestoreDocumentModel: Codable> = (DomainModel) -> FirestoreDocumentModel

public class FirestoreDocumentWriter<T, FirestoreDocumentModel: Codable > {
    var listenerRegistration: ListenerRegistration?
    let document: FirebaseDocument
//    typealias ErrorMapper = ((Error) -> Err)
//    let errorMapper: ErrorMapper
    let mapper: FireStoreDocumentMapper<T, FirestoreDocumentModel>
    init(document: FirebaseDocument, mapper: @escaping FireStoreDocumentMapper<T, FirestoreDocumentModel>){
        self.document = document
//        self.errorMapper = errorMapper
        self.mapper = mapper
    }
    init(document: FirebaseDocument) where T == FirestoreDocumentModel{
        self.document = document
        self.mapper = {return $0}
    }
    public func save(_ item: T) throws{
        let firItem = mapper(item)

        do{
            try document.setData(from: firItem){ error in
            if let error = error{
                
                print("---- error ----")
                print(type(of: error))
                print(error.localizedDescription)
                print("---- end error ----")
            }
            print("callback from update doc")
        }
        } catch{
            throw DSError.GeneralError("could not save item : \(document.documentID)", error)
        }
        print("\(document.documentID) has been updated with callback")
    }
    public func delete() throws{
        
        document.delete{ error in
            if let error = error{
                
                print("---- error ----")
                print(type(of: error))
                print(error.localizedDescription)
                print("---- end error ----")
            }
            print("callback from update doc")
        }
        print("\(document.documentID) has been updated with callback")
    }
    public func unsubscribe(){
        self.listenerRegistration = nil
    }
}
