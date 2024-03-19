//
//  FirestoreDataListener.swift
//  HealthJournal
//
//  Created by matt naples on 12/8/22.
//

import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift


public typealias QueryBuilder = (CollectionReference) -> Query
public class FirestoreDataListener<T: Codable>{
    deinit{
        let registrations = listenerRegistrations.values
        registrations.forEach{$0.remove()}
    }
    let decodingProblemThreshold: Double = 0.5
    private let id = Int.random(in: 1...10000)
    private let collection: CollectionReference
    var listenerRegistrations: [UUID: ListenerRegistration] =  [:]{
        didSet{
            print("firestorelistener \(id) now has \(listenerRegistrations.values.count)")
        }
    }
//    let errorMapper: ErrorMapper
//    typealias ErrorMapper = ((Error) -> Err)

    public init(query: CollectionReference){
        self.collection = query
    }
    
    private func getListener(queryBuilder: QueryBuilder,handler:  @escaping ((Result<[T],Error>)->Void)) -> ListenerRegistration{
        let queryToSubscribeTo = queryBuilder(collection)
        let registration = queryToSubscribeTo.addSnapshotListener { snapshot, anError in
            var result: Result<[T], Error>

            if let err = anError {
                result = .failure(DSError.GeneralError("An error occurred while fetching data from the network", err))
                handler(result)
                return
            }
            
            guard let documents = snapshot?.documents else{
                result = .failure(DSError.GeneralError("the snapshot was empty", nil))
                handler(result)
                return
            }
            
//             we should definitely not throw an error here... pass an empty array dummy
//            guard !documents.isEmpty else{
//                result = .failure(DSError.NotFound("no documents exist in the given collection"))
//                handler(result)
//                return
//            }
            var resultingObjects = [T]()
            var decodingProblems = [CodingProblem]()
            for doc in documents{
                do{
                    let obj = try doc.data(as: T.self)
                    resultingObjects.append(obj)
                }
                catch{
                    decodingProblems.append(CodingProblem(problemQuerySnapshot: doc, error: error))
                }
            }
            guard documents.count == 0 || (Double(decodingProblems.count)/Double(documents.count) < self.decodingProblemThreshold) else{
                result = .failure(DSError.CouldNotDecode("\(Double(decodingProblems.count)/Double(documents.count)) of all documents in the collection failed to be retrieved, or \(decodingProblems.count) total.", decodingProblems))
                handler(result)
                return
            }
            result = .success(resultingObjects)
            handler(result)
        }
        
        return registration
    }
    private func getDocChangesListener(handler:  @escaping ((Result<[(DocumentChangeType, T)],DSError>)->Void)) -> ListenerRegistration{
        let registration = collection.addSnapshotListener { snapshot, anError in
            var result: Result<[(DocumentChangeType, T)], DSError>
            print("doc changes info...")
            print(snapshot?.documentChanges.map(\.type.description))
            print(snapshot?.documentChanges.map(\.oldIndex))
            print(snapshot?.documentChanges.map(\.newIndex))


            if let err = anError {
                result = .failure(DSError.GeneralError("An error occurred while fetching data from the network", err))
                handler(result)
                return
            }
            
            guard let documentChanges = snapshot?.documentChanges else{
                result = .failure(DSError.GeneralError("the snapshot was empty", nil))
                handler(result)
                return
            }
            
//             we should definitely not throw an error here... pass an empty array dummy
//            guard !documents.isEmpty else{
//                result = .failure(DSError.NotFound("no documents exist in the given collection"))
//                handler(result)
//                return
//            }
            
            var resultingObjects = [(DocumentChangeType,T)]()
            var decodingProblems = [CodingProblem]()
            for docChange in documentChanges{
                do{
                    let doc = docChange.document
                    let changeType = docChange.type
                    let obj = try doc.data(as: T.self)
                    resultingObjects.append((changeType,obj))
                    
                }
                catch{
                    decodingProblems.append(CodingProblem(problemQuerySnapshot: docChange.document, error: error))
                }
            }
            guard documentChanges.count == 0 || (Double(decodingProblems.count)/Double(documentChanges.count) < self.decodingProblemThreshold) else{
                result = .failure(.CouldNotDecode("\(Double(decodingProblems.count)/Double(documentChanges.count)) of all documents in the collection failed to be retrieved, or \(decodingProblems.count) total.", decodingProblems))
                handler(result)
                return
            }
            result = .success(resultingObjects)
            handler(result)
        }
        
        return registration
    }

    public func subscribe(to queryBuilder: QueryBuilder = {$0},_ onUpdate: @escaping (Result<[T],Error>) -> Void) -> UUID {
        let listenerId = UUID()
        
        self.listenerRegistrations[listenerId] = getListener(queryBuilder: queryBuilder, handler: onUpdate)
        print("firestoreListener added subscriber \(listenerId) \(type(of: T.self)) current subscription count \(listenerRegistrations.values.count)")
        return listenerId
    }
    public func subscribeToChanges(_ onUpdate: @escaping (Result<[(DocumentChangeType, T)],DSError>) -> Void) -> UUID {
        let listenerId = UUID()
        self.listenerRegistrations[listenerId] = getDocChangesListener( handler: onUpdate)
        return listenerId
    }
  
    
    public func unsubscribe(_ subscriptionId: UUID) {
        if let listener = self.listenerRegistrations.removeValue(forKey: subscriptionId){
            listener.remove()
        }
        print("firestoreListener unsubscribed \(subscriptionId)... current subscription count \(listenerRegistrations.values.count)")
    }
    ///loads all data from the query and maps them to throws if documents cannot be retrieved or decoded
    public func loadData(source: FirestoreSource) async throws -> [T]{
        let querySnapshot = try await collection.getDocuments(source: source)
        return try querySnapshot.documents.compactMap{doc in
            return try doc.data(as: T.self)
        }
    }
    
    public func subscribeOnDatesBetween(startDate: Date, and endDate: Date,dateFieldPath: String,onUpdate: @escaping (Result<[T],Error>) -> Void) -> UUID {
        let listenerId = UUID()
        let queryBuilder: QueryBuilder = {
            $0.whereFieldIsBetween(dateFieldPath, startDate: startDate, endDate: endDate)
        }
        self.listenerRegistrations[listenerId] = self.getListener(queryBuilder: queryBuilder, handler: onUpdate)
        print("firestoreListener added subscriber \(listenerId) \(type(of: T.self)) current subscription count \(listenerRegistrations.values.count)")
        return listenerId
    }
    typealias Item = T
}
public class FirestoreDataLoader<T: Codable> {
    
    private let collection: CollectionReference
    public init(collection: CollectionReference){
        self.collection = collection
    }
    
    ///loads all data from the query and maps them to throws if documents cannot be retrieved or decoded
    public func loadData(source: FirestoreSource, queryBuilder: QueryBuilder) async throws -> [T]{
        let q = queryBuilder(self.collection)
        
        let querySnapshot = try await q.getDocuments(source: source)
        return try querySnapshot.documents.compactMap{doc in
            return try doc.data(as: T.self)
        }
    }
    public func loadData(source: FirestoreSource,queryBuilder: QueryBuilder ,completion: @escaping (Result<[T],Error>) -> Void){
        let q = queryBuilder(self.collection)
        q.getDocuments(source: source) { snapshot, error in
            if let error = error{
                completion(.failure(error))
            } else {
                guard let snapshot = snapshot else{
                    completion(.success([]))
                    return
                }
                var codingProblems: [CodingProblem] = []
                var items: [T] = []
                for doc in snapshot.documents{
                    do{
                        let item = try doc.data(as: T.self)
                        items.append(item)
                    } catch{
                        codingProblems.append(CodingProblem(problemDocumentSnapshot: doc, error: error))
                    }
                }
                if Double(codingProblems.count)/Double(snapshot.count) > 0.1{
                    completion(.failure(DSError.CouldNotDecode("There was a problem decoding data.", codingProblems)))
                } else{
                    completion(.success(items))
                }
            }
        }
    }
}


public enum DSError: Error{
    case NotFound(String)
    case AlreadyExists(String)
    case CouldNotDecode(String, [CodingProblem])
    case CouldNodeEncode(String, [CodingProblem])
    case GeneralError(String, Error?)
    var message: String{
        switch self {
        case .NotFound(let string):
            return string
        case .AlreadyExists(let string):
            return string
        case .CouldNotDecode(let string, let array):
            return string
        case .CouldNodeEncode(let string, let array):
            return string
        case .GeneralError(let string, let optional):
            return string
        }
    }
}


extension DocumentChangeType{
    var description: String{
        switch self{
        case .added: return "added"
        case .modified: return "modified"
        case .removed: return "removed"
        }
    }
}
