//
//  File.swift
//  FirestoreService
//
//  Created by matt naples on 1/15/25.
//

import Foundation
import Combine
import FirebaseFirestore
import FirebaseFirestoreCombineSwift
struct CodingProblem2{
    let problemQuerySnapshot: FirestoreDocumentSnapshot?
    let problemDocumentSnapshot: DocumentSnapshot?
    let error: Error
    init(problemQuerySnapshot: FirestoreDocumentSnapshot, error: Error){
        self.problemQuerySnapshot = problemQuerySnapshot
        self.error = error
        self.problemDocumentSnapshot = nil
        
    }
    
    init(problemDocumentSnapshot: DocumentSnapshot, error: Error){
        self.problemDocumentSnapshot = problemDocumentSnapshot
        self.error = error
        self.problemQuerySnapshot = nil
    }
}
enum DSError2: Error{
    case NotFound(String)
    case AlreadyExists(String)
    case CouldNotDecode(String, [CodingProblem2])
    case CouldNodeEncode(String, [CodingProblem2])
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



public class FirestoreSubscriptionManager<T, FCollection: FirestoreCollection> where T: Codable {
    public typealias QueryBuilder2 = (FCollection) -> FirestoreQuery
    let decodingProblemThreshold: Double = 0.5

    private var cancellables: [UUID: AnyCancellable] = [:]
    private let lock = NSLock()

    /// The Firestore collection interface
    private let collection: FCollection

    /// Initialize with any object conforming to `FirestoreCollection`
    public init(collection: FCollection) {
        self.collection = collection
    }
//    static let shared = FirestoreSubscriptionManager<T>()

    public func subscribeToTwoCollections<
        T2: Codable,
        FCollection2: FirestoreCollection
    >(
        secondCollection: FCollection2,
        queryBuilder1: @escaping QueryBuilder2 = { $0 },
        queryBuilder2: @escaping (FCollection2) -> FirestoreQuery,
        onUpdate: @escaping (Result<([T], [T2]), Error>) -> Void
    ) -> UUID {
        
        let subscriptionID = UUID()
        
        // Build the two queries
        let publisher1 = queryBuilder1(collection).snapshotPublisher()
        let publisher2 = queryBuilder2(secondCollection).snapshotPublisher()
        
        // Combine them via combineLatest
        let combinedPublisher = publisher1
            .combineLatest(publisher2)
            .map { (snapshot1, snapshot2) -> Result<([T], [T2]), Error> in
                // Decode first snapshot into array of T
                let documents1 = snapshot1.allDocuments
                var objects1 = [T]()
                var decodingProblems1 = [CodingProblem2]()
                
                for doc in documents1 {
                    do {
                        let obj = try doc.data(as: T.self)
                        objects1.append(obj)
                    } catch {
                        decodingProblems1.append(
                            CodingProblem2(problemQuerySnapshot: doc, error: error)
                        )
                    }
                }
                
                // Decode second snapshot into array of T2
                let documents2 = snapshot2.allDocuments
                var objects2 = [T2]()
                var decodingProblems2 = [CodingProblem2]()
                
                for doc in documents2 {
                    do {
                        let obj = try doc.data(as: T2.self)
                        objects2.append(obj)
                    } catch {
                        decodingProblems2.append(
                            CodingProblem2(problemQuerySnapshot: doc, error: error)
                        )
                    }
                }

                // Check decoding thresholds
                let ratio1 = documents1.count == 0
                    ? 0
                    : Double(decodingProblems1.count)/Double(documents1.count)
                let ratio2 = documents2.count == 0
                    ? 0
                    : Double(decodingProblems2.count)/Double(documents2.count)
                
                // If either ratio is above the threshold, fail
                if ratio1 >= self.decodingProblemThreshold {
                    let error = DSError2.CouldNotDecode(
                        "First collection had a decoding failure ratio of \(ratio1), or \(decodingProblems1.count) total.",
                        decodingProblems1
                    )
                    return .failure(error)
                }
                
                if ratio2 >= self.decodingProblemThreshold {
                    let error = DSError2.CouldNotDecode(
                        "Second collection had a decoding failure ratio of \(ratio2), or \(decodingProblems2.count) total.",
                        decodingProblems2
                    )
                    return .failure(error)
                }
                
                return .success((objects1, objects2))
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
        
        lock.lock()
        defer { lock.unlock() }
        
        let cancellable = combinedPublisher
            .sink(receiveCompletion: { completion in
                if case let .failure(error) = completion {
                    onUpdate(.failure(error))
                }
            }, receiveValue: { result in
                onUpdate(result)
            })
        
        cancellables[subscriptionID] = cancellable
        return subscriptionID
    }
    public func subscribeToCollectionAndDocument<T2: Decodable>(
        documentReference: FirestoreDocumentReference,
        documentType: T2.Type,
        queryBuilder1: @escaping QueryBuilder2 = { $0 },
        onUpdate: @escaping (Result<([T], T2), Error>) -> Void
    ) -> UUID {
        
        let subscriptionID = UUID()
        print("creating subscription id: \(subscriptionID)")
        // Build the two queries
        let publisher1 = queryBuilder1(collection).snapshotPublisher()
        let publisher2 = documentReference.snapshotPublisher()
        print("created publishers for doc and collection")

        // Combine them via combineLatest
        let combinedPublisher = publisher1
            .combineLatest(publisher2)
            .map { (snapshot1, snapshot2) -> Result<([T], T2), Error> in
                // Decode first snapshot into array of T
                let documents1 = snapshot1.allDocuments
                var objects1 = [T]()
                var decodingProblems1 = [CodingProblem2]()
                
                for doc in documents1 {
                    do {
                        let obj = try doc.data(as: T.self)
                        objects1.append(obj)
                    } catch {
                        decodingProblems1.append(
                            CodingProblem2(problemQuerySnapshot: doc, error: error)
                        )
                    }
                }
                
                var obj2: T2
                // Decode second snapshot document
                do {
                    obj2 = try snapshot2.data(as: T2.self)
                } catch {
                    print("updating failure for document: \(error)")
                    return .failure(error)
                }
            
                // Check decoding thresholds
                let ratio1 = documents1.count == 0
                    ? 0
                    : Double(decodingProblems1.count)/Double(documents1.count)
   
                // If either ratio is above the threshold, fail
                if ratio1 >= self.decodingProblemThreshold {
                    let error = DSError2.CouldNotDecode(
                        "First collection had a decoding failure ratio of \(ratio1), or \(decodingProblems1.count) total.",
                        decodingProblems1
                    )
                    print("updating failure for collection: \(error)")
                    return .failure(error)
                }
                
                return .success((objects1, obj2))
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
        
        lock.lock()
        defer { lock.unlock() }
        
        let cancellable = combinedPublisher
            .sink(receiveCompletion: { completion in
                print("completion received: \(completion)")
                if case let .failure(error) = completion {
                    onUpdate(.failure(error))
                }
            }, receiveValue: { result in
                onUpdate(result)
            })
        
        cancellables[subscriptionID] = cancellable
        return subscriptionID
    }
    public func subscribeToThreeCollections<
        T2: Codable,
        T3: Codable,
        FCollection2: FirestoreCollection,
        FCollection3: FirestoreCollection
    >(
        secondCollection: FCollection2,
        thirdCollection: FCollection3,
        queryBuilder1: @escaping QueryBuilder2 = { $0 },
        queryBuilder2: @escaping (FCollection2) -> FirestoreQuery,
        queryBuilder3: @escaping (FCollection3) -> FirestoreQuery,
        onUpdate: @escaping (Result<([T], [T2], [T3]), Error>) -> Void
    ) -> UUID {
        
        let subscriptionID = UUID()
        
        // Build the three queries
        let publisher1 = queryBuilder1(collection).snapshotPublisher()
        let publisher2 = queryBuilder2(secondCollection).snapshotPublisher()
        let publisher3 = queryBuilder3(thirdCollection).snapshotPublisher()
        
        // Combine them via combineLatest
        let combinedPublisher = publisher1
            .combineLatest(publisher2, publisher3)
            .map { (snapshot1, snapshot2, snapshot3) -> Result<([T], [T2], [T3]), Error> in
                // Decode first snapshot into array of T
                let documents1 = snapshot1.allDocuments
                var objects1 = [T]()
                var decodingProblems1 = [CodingProblem2]()
                
                for doc in documents1 {
                    do {
                        let obj = try doc.data(as: T.self)
                        objects1.append(obj)
                    } catch {
                        decodingProblems1.append(
                            CodingProblem2(problemQuerySnapshot: doc, error: error)
                        )
                    }
                }
                
                // Decode second snapshot into array of T2
                let documents2 = snapshot2.allDocuments
                var objects2 = [T2]()
                var decodingProblems2 = [CodingProblem2]()
                
                for doc in documents2 {
                    do {
                        let obj = try doc.data(as: T2.self)
                        objects2.append(obj)
                    } catch {
                        decodingProblems2.append(
                            CodingProblem2(problemQuerySnapshot: doc, error: error)
                        )
                    }
                }

                // Decode third snapshot into array of T3
                let documents3 = snapshot3.allDocuments
                var objects3 = [T3]()
                var decodingProblems3 = [CodingProblem2]()
                
                for doc in documents3 {
                    do {
                        let obj = try doc.data(as: T3.self)
                        objects3.append(obj)
                    } catch {
                        decodingProblems3.append(
                            CodingProblem2(problemQuerySnapshot: doc, error: error)
                        )
                    }
                }

                // Check decoding thresholds
                let ratio1 = documents1.count == 0
                    ? 0
                    : Double(decodingProblems1.count) / Double(documents1.count)
                let ratio2 = documents2.count == 0
                    ? 0
                    : Double(decodingProblems2.count) / Double(documents2.count)
                let ratio3 = documents3.count == 0
                    ? 0
                    : Double(decodingProblems3.count) / Double(documents3.count)
                
                // If any ratio is above the threshold, fail
                if ratio1 >= self.decodingProblemThreshold {
                    let error = DSError2.CouldNotDecode(
                        "First collection had a decoding failure ratio of \(ratio1), or \(decodingProblems1.count) total.",
                        decodingProblems1
                    )
                    return .failure(error)
                }
                
                if ratio2 >= self.decodingProblemThreshold {
                    let error = DSError2.CouldNotDecode(
                        "Second collection had a decoding failure ratio of \(ratio2), or \(decodingProblems2.count) total.",
                        decodingProblems2
                    )
                    return .failure(error)
                }

                if ratio3 >= self.decodingProblemThreshold {
                    let error = DSError2.CouldNotDecode(
                        "Third collection had a decoding failure ratio of \(ratio3), or \(decodingProblems3.count) total.",
                        decodingProblems3
                    )
                    return .failure(error)
                }
                
                return .success((objects1, objects2, objects3))
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
        
        lock.lock()
        defer { lock.unlock() }
        
        let cancellable = combinedPublisher
            .sink(receiveCompletion: { completion in
                if case let .failure(error) = completion {
                    onUpdate(.failure(error))
                }
            }, receiveValue: { result in
                onUpdate(result)
            })
        
        cancellables[subscriptionID] = cancellable
        return subscriptionID
    }

    public func subscribe(to queryBuilder: @escaping QueryBuilder2 = {$0},_ onUpdate: @escaping (Result<[T],Error>) -> Void) -> UUID {
        let subscriptionID = UUID()
        let query = queryBuilder(collection)
        let publisher = query.snapshotPublisher()

        lock.lock()
        defer { lock.unlock() }

        let cancellable = publisher
            .map { snapshot -> Result<[T], Error> in
                let documents = snapshot.allDocuments
                var resultingObjects = [T]()
                var decodingProblems = [CodingProblem2]()
                for doc in documents {
                    do {
                        let obj = try doc.data(as: T.self)
                        resultingObjects.append(obj)
                    }
                    catch {
                        decodingProblems.append(CodingProblem2(problemQuerySnapshot: doc, error: error))
                    }
                }
                guard documents.count == 0 || (Double(decodingProblems.count)/Double(documents.count) < self.decodingProblemThreshold) else {
                    return .failure(DSError2.CouldNotDecode("\(Double(decodingProblems.count)/Double(documents.count)) of all documents in the collection failed to be retrieved, or \(decodingProblems.count) total.", decodingProblems))
                }
                return .success(resultingObjects)
            }
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case let .failure(error) = completion {
                        onUpdate(.failure(error))
                    }
                },
                receiveValue: { result in
                    onUpdate(result)
                }
            )

        cancellables[subscriptionID] = cancellable
        return subscriptionID
    }
    
    

    public func unsubscribe(_ subscriptionID: UUID) {
        lock.lock()
        defer { lock.unlock() }

        cancellables[subscriptionID]?.cancel()
        cancellables.removeValue(forKey: subscriptionID)
    }

    
    public func unsubscribeAll() {
        lock.lock()
        defer { lock.unlock() }

        cancellables.forEach { $1.cancel() }
        cancellables.removeAll()
    }


}



/// Typealias for a query builder closure


extension QuerySnapshot: FirestoreQuerySnapshot{
    public var allDocuments: [any FirestoreDocumentSnapshot] {
        self.documents.map{ $0 as FirestoreDocumentSnapshot }
    }
}

//extension QueryDocumentSnapshot: FirestoreDocumentSnapshot{
//    public func data<T>(as type: T.Type) throws -> T where T : Decodable {
//        return try self.data(as: type, with: .none, decoder: .init())
//    }
//    
//}


extension Query: FirestoreQuery {
    public func snapshotPublisher() -> AnyPublisher<FirestoreQuerySnapshot, Error> {
         return self
            .snapshotPublisher(includeMetadataChanges: false)
            .map { $0 as FirestoreQuerySnapshot }
            .eraseToAnyPublisher()
    }
}

/// A protocol that represents a Firestore-like collection
public protocol FirestoreCollection: FirestoreQuery {
//    func asQuery() -> FirestoreQuery
    // Add more query-building functions as needed...
//    func getDocument(_ documentPath: String) -> FirestoreDocumentSnapshot
}
public protocol FirestoreDocumentReference{
    func snapshotPublisher() -> AnyPublisher<FirestoreDocumentSnapshot, Error>

}
/// A protocol that represents a Firestore-like query
public protocol FirestoreQuery {
    func snapshotPublisher() -> AnyPublisher<FirestoreQuerySnapshot, Error>
}

/// A protocol that represents the snapshot you receive from a query
public protocol FirestoreQuerySnapshot {
    var allDocuments: [FirestoreDocumentSnapshot] { get }
}

/// A protocol that represents an individual document snapshot
public protocol FirestoreDocumentSnapshot {
    /// Returns the raw data for decoding
    func data()  -> [String: Any]?
    func data<T: Decodable>(as type: T.Type) throws -> T
}
extension DocumentSnapshot: FirestoreDocumentSnapshot{

    
    public func data<T>(as type: T.Type) throws -> T where T : Decodable {
        return try self.data(as: type, with: .none, decoder: .init())
    }
    
    
    
}

extension CollectionReference: FirestoreCollection {
   
 
}
extension DocumentReference: FirestoreDocumentReference{
    public func snapshotPublisher() -> AnyPublisher<FirestoreDocumentSnapshot, Error> {
        return self.snapshotPublisher(includeMetadataChanges: false)
            .map{ $0 as FirestoreDocumentSnapshot }
            .eraseToAnyPublisher()
    }
}

private struct FirestoreQuerySnapshotImpl: FirestoreQuerySnapshot {
    let snapshot: QuerySnapshot
    
    var allDocuments: [FirestoreDocumentSnapshot] {
        snapshot.documents.map {
            FirestoreDocumentSnapshotImpl(document: $0)
        }
    }
}

private struct FirestoreDocumentSnapshotImpl: FirestoreDocumentSnapshot {
    func data<T:Decodable>(as type: T.Type) throws -> T {
        try document.data(as: type.self)
    }
    
    let document: QueryDocumentSnapshot

    func data() -> [String: Any]? {
        // For a typical Firestore doc, `data()` is guaranteed.
        return document.data()
    }
}
