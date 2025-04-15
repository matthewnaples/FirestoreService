//
//  File.swift
//  FirestoreService
//
//  Created by matt naples on 1/16/25.
//

import Foundation
import Combine


protocol CollectionKnowledgable{
   static var collection: FirestoreCollection {get}
}
//in service module
protocol MockService{
    func subscribe(onUpdate: @escaping (Result<[MockModel], Error>) -> Void) -> UUID
    func unsubscribe(_ token: UUID)
}

//in application module
extension FirestoreSubscriptionListener: MockService{
}
extension FirestoreSubscriptionListener{
   func subscribe<Item>(onUpdate: @escaping (Result<[Item], any Error>) -> Void) -> UUID where Item : Codable & CollectionKnowledgable {
       self.subscribe(query: Item.collection, onUpdate: onUpdate)
   }
}

public class FirestoreSubscriptionListener {
    
    private var cancellables: [UUID: AnyCancellable] = [:]
    private let lock = NSLock()

    public init() { }

    /// Subscribe to a single collection with transformation
    /// - Parameters:
    ///   - query: The Firestore query to subscribe to
    ///   - transformation: Transformation closure that runs on a background thread
    ///   - onUpdate: Callback with the transformed result on the main thread
    /// - Returns: Subscription token that can be used to unsubscribe
    public func subscribe<T: Codable, Output>(
        query: FirestoreQuery,
        transformation: @escaping ([T]) -> Result<Output, Error>,
        onUpdate: @escaping (Result<Output, Error>) -> Void
    ) -> UUID {
        let subscriptionID = UUID()
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
                    } catch {
                        decodingProblems.append(CodingProblem2(problemQuerySnapshot: doc, error: error))
                    }
                }

                guard documents.isEmpty ||
                      (Double(decodingProblems.count) / Double(documents.count)
                       < 0.5 /* or your threshold */) else {
                    let ratio = Double(decodingProblems.count) / Double(documents.count)
                    return .failure(
                        DSError2.CouldNotDecode(
                            "\(ratio * 100)% of the docs failed to decode.", decodingProblems
                        )
                    )
                }

                return .success(resultingObjects)
            }
            .map { result -> Result<Output, Error> in
                switch result {
                case .success(let items):
                    return transformation(items)
                case .failure(let error):
                    return .failure(error)
                }
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

    /// Subscribe to a single collection without transformation
    /// - Parameters:
    ///   - query: The Firestore query to subscribe to
    ///   - onUpdate: Callback with the query result on the main thread
    /// - Returns: Subscription token that can be used to unsubscribe
    public func subscribe<T: Codable>(
        query: FirestoreQuery,
        onUpdate: @escaping (Result<[T], Error>) -> Void
    ) -> UUID {
        return subscribe(
            query: query,
            transformation: { .success($0) },
            onUpdate: onUpdate
        )
    }

    /// Subscribe to two collections with transformation
    /// - Parameters:
    ///   - query1: First Firestore query
    ///   - query2: Second Firestore query
    ///   - transformation: Transformation closure that runs on a background thread
    ///   - onUpdate: Callback with the transformed result on the main thread
    /// - Returns: Subscription token that can be used to unsubscribe
    public func subscribeToTwoCollections<
        T: Codable,
        T2: Codable,
        Query1: FirestoreQuery,
        Query2: FirestoreQuery,
        Output
    >(
        query1: Query1,
        query2: Query2,
        transformation: @escaping (([T], [T2])) -> Result<Output, Error>,
        onUpdate: @escaping (Result<Output, Error>) -> Void
    ) -> UUID {
        let subscriptionID = UUID()
    
        let publisher1 = query1.snapshotPublisher()
        let publisher2 = query2.snapshotPublisher()
        
        let combined = publisher1.combineLatest(publisher2)

        lock.lock()
        defer { lock.unlock() }

        let cancellable = combined
            .map { (snapshot1, snapshot2) -> Result<([T], [T2]), Error> in
                // Decode snapshot1 -> [T]
                let documents1 = snapshot1.allDocuments
                var objects1 = [T]()
                var decodingProblems1 = [CodingProblem2]()
                for doc in documents1 {
                    do {
                        objects1.append(try doc.data(as: T.self))
                    } catch {
                        decodingProblems1.append(CodingProblem2(problemQuerySnapshot: doc, error: error))
                    }
                }

                // Decode snapshot2 -> [T2]
                let documents2 = snapshot2.allDocuments
                var objects2 = [T2]()
                var decodingProblems2 = [CodingProblem2]()
                for doc in documents2 {
                    do {
                        objects2.append(try doc.data(as: T2.self))
                    } catch {
                        decodingProblems2.append(CodingProblem2(problemQuerySnapshot: doc, error: error))
                    }
                }

                // Example threshold logic:
                let ratio1 = documents1.isEmpty ? 0 : Double(decodingProblems1.count) / Double(documents1.count)
                let ratio2 = documents2.isEmpty ? 0 : Double(decodingProblems2.count) / Double(documents2.count)
                let threshold = 0.5
                
                if ratio1 >= threshold {
                    return .failure(
                        DSError2.CouldNotDecode("Decoding failure ratio for first query: \(ratio1)", decodingProblems1)
                    )
                }
                if ratio2 >= threshold {
                    return .failure(
                        DSError2.CouldNotDecode("Decoding failure ratio for second query: \(ratio2)", decodingProblems2)
                    )
                }

                return .success((objects1, objects2))
            }
            .map { result -> Result<Output, Error> in
                switch result {
                case .success(let items):
                    return transformation(items)
                case .failure(let error):
                    return .failure(error)
                }
            }
            .receive(on: DispatchQueue.main)
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

    /// Subscribe to two collections without transformation
    /// - Parameters:
    ///   - query1: First Firestore query
    ///   - query2: Second Firestore query
    ///   - onUpdate: Callback with the query results on the main thread
    /// - Returns: Subscription token that can be used to unsubscribe
    public func subscribeToTwoCollections<
        T: Codable,
        T2: Codable,
        Query1: FirestoreQuery,
        Query2: FirestoreQuery
    >(
        query1: Query1,
        query2: Query2,
        onUpdate: @escaping (Result<([T], [T2]), Error>) -> Void
    ) -> UUID {
        return subscribeToTwoCollections(
            query1: query1,
            query2: query2,
            transformation: { .success($0) },
            onUpdate: onUpdate
        )
    }

    /// Subscribe to three collections with transformation
    /// - Parameters:
    ///   - query1: First Firestore query
    ///   - query2: Second Firestore query
    ///   - query3: Third Firestore query
    ///   - transformation: Transformation closure that runs on a background thread
    ///   - onUpdate: Callback with the transformed result on the main thread
    /// - Returns: Subscription token that can be used to unsubscribe
    public func subscribeToThreeCollections<
        T: Codable,
        T2: Codable,
        T3: Codable,
        Query1: FirestoreQuery,
        Query2: FirestoreQuery,
        Query3: FirestoreQuery,
        Output
    >(
        query1: Query1,
        query2: Query2,
        query3: Query3,
        transformation: @escaping (([T], [T2], [T3])) -> Result<Output, Error>,
        onUpdate: @escaping (Result<Output, Error>) -> Void
    ) -> UUID {
        let subscriptionID = UUID()
    
        let publisher1 = query1.snapshotPublisher()
        let publisher2 = query2.snapshotPublisher()
        let publisher3 = query3.snapshotPublisher()
        
        let combined = publisher1.combineLatest(publisher2, publisher3)

        lock.lock()
        defer { lock.unlock() }

        let cancellable = combined
            .map { (snapshot1, snapshot2, snapshot3) -> Result<([T], [T2], [T3]), Error> in
                // Decode snapshot1 -> [T]
                let documents1 = snapshot1.allDocuments
                var objects1 = [T]()
                var decodingProblems1 = [CodingProblem2]()
                for doc in documents1 {
                    do {
                        objects1.append(try doc.data(as: T.self))
                    } catch {
                        decodingProblems1.append(CodingProblem2(problemQuerySnapshot: doc, error: error))
                    }
                }

                // Decode snapshot2 -> [T2]
                let documents2 = snapshot2.allDocuments
                var objects2 = [T2]()
                var decodingProblems2 = [CodingProblem2]()
                for doc in documents2 {
                    do {
                        objects2.append(try doc.data(as: T2.self))
                    } catch {
                        decodingProblems2.append(CodingProblem2(problemQuerySnapshot: doc, error: error))
                    }
                }

                // Decode snapshot3 -> [T3]
                let documents3 = snapshot3.allDocuments
                var objects3 = [T3]()
                var decodingProblems3 = [CodingProblem2]()
                for doc in documents3 {
                    do {
                        objects3.append(try doc.data(as: T3.self))
                    } catch {
                        decodingProblems3.append(CodingProblem2(problemQuerySnapshot: doc, error: error))
                    }
                }

                // Example threshold logic:
                let ratio1 = documents1.isEmpty ? 0 : Double(decodingProblems1.count) / Double(documents1.count)
                let ratio2 = documents2.isEmpty ? 0 : Double(decodingProblems2.count) / Double(documents2.count)
                let ratio3 = documents3.isEmpty ? 0 : Double(decodingProblems3.count) / Double(documents3.count)
                let threshold = 0.5
                
                if ratio1 >= threshold {
                    return .failure(
                        DSError2.CouldNotDecode("Decoding failure ratio for first query: \(ratio1)", decodingProblems1)
                    )
                }
                if ratio2 >= threshold {
                    return .failure(
                        DSError2.CouldNotDecode("Decoding failure ratio for second query: \(ratio2)", decodingProblems2)
                    )
                }
                if ratio3 >= threshold {
                    return .failure(
                        DSError2.CouldNotDecode("Decoding failure ratio for third query: \(ratio3)", decodingProblems3)
                    )
                }

                return .success((objects1, objects2, objects3))
            }
            .map { result -> Result<Output, Error> in
                switch result {
                case .success(let items):
                    return transformation(items)
                case .failure(let error):
                    return .failure(error)
                }
            }
            .receive(on: DispatchQueue.main)
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

    /// Subscribe to three collections without transformation
    /// - Parameters:
    ///   - query1: First Firestore query
    ///   - query2: Second Firestore query
    ///   - query3: Third Firestore query
    ///   - onUpdate: Callback with the query results on the main thread
    /// - Returns: Subscription token that can be used to unsubscribe
    public func subscribeToThreeCollections<
        T: Codable,
        T2: Codable,
        T3: Codable,
        Query1: FirestoreQuery,
        Query2: FirestoreQuery,
        Query3: FirestoreQuery
    >(
        query1: Query1,
        query2: Query2,
        query3: Query3,
        onUpdate: @escaping (Result<([T], [T2], [T3]), Error>) -> Void
    ) -> UUID {
        return subscribeToThreeCollections(
            query1: query1,
            query2: query2,
            query3: query3,
            transformation: { .success($0) },
            onUpdate: onUpdate
        )
    }

    /// Subscribe to three documents with transformation
    /// - Parameters:
    ///   - doc1: First document reference
    ///   - doc2: Second document reference
    ///   - doc3: Third document reference
    ///   - transformation: Transformation closure that runs on a background thread
    ///   - onUpdate: Callback with the transformed result on the main thread
    /// - Returns: Subscription token that can be used to unsubscribe
    public func subscribeToThreeDocuments<
        T: Codable,
        T2: Codable,
        T3: Codable,
        Output
    >(
        doc1: FirestoreDocumentReference,
        doc2: FirestoreDocumentReference,
        doc3: FirestoreDocumentReference,
        transformation: @escaping ((T, T2, T3)) -> Result<Output, Error>,
        onUpdate: @escaping (Result<Output, Error>) -> Void
    ) -> UUID {
        let subscriptionID = UUID()
    
        let publisher1 = doc1.snapshotPublisher()
        let publisher2 = doc2.snapshotPublisher()
        let publisher3 = doc3.snapshotPublisher()
        
        let combined = publisher1.combineLatest(publisher2, publisher3)

        lock.lock()
        defer { lock.unlock() }

        let cancellable = combined
            .map { (snapshot1, snapshot2, snapshot3) -> Result<(T, T2, T3), Error> in
                do {
                    let item1 = try snapshot1.data(as: T.self)
                    let item2 = try snapshot2.data(as: T2.self)
                    let item3 = try snapshot3.data(as: T3.self)
                    
                    return .success((item1, item2, item3))
                } catch {
                    return .failure(DSError2.CouldNotDecode("Failed to decode one or more documents", []))
                }
            }
            .map { result -> Result<Output, Error> in
                switch result {
                case .success(let items):
                    return transformation(items)
                case .failure(let error):
                    return .failure(error)
                }
            }
            .receive(on: DispatchQueue.main)
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

    /// Subscribe to three documents without transformation
    /// - Parameters:
    ///   - doc1: First document reference
    ///   - doc2: Second document reference
    ///   - doc3: Third document reference
    ///   - onUpdate: Callback with the document data on the main thread
    /// - Returns: Subscription token that can be used to unsubscribe
    public func subscribeToThreeDocuments<
        T: Codable,
        T2: Codable,
        T3: Codable
    >(
        doc1: FirestoreDocumentReference,
        doc2: FirestoreDocumentReference,
        doc3: FirestoreDocumentReference,
        onUpdate: @escaping (Result<(T, T2, T3), Error>) -> Void
    ) -> UUID {
        return subscribeToThreeDocuments(
            doc1: doc1,
            doc2: doc2,
            doc3: doc3,
            transformation: { .success($0) },
            onUpdate: onUpdate
        )
    }

    /// Subscribe to one collection and one document with transformation
    /// - Parameters:
    ///   - query: The collection query
    ///   - doc: Document reference
    ///   - transformation: Transformation closure that runs on a background thread
    ///   - onUpdate: Callback with the transformed result on the main thread
    /// - Returns: Subscription token that can be used to unsubscribe
    public func subscribeToCollectionAndDocument<
        T: Codable,
        T2: Codable,
        Query: FirestoreQuery,
        Output
    >(
        query: Query,
        doc: FirestoreDocumentReference,
        transformation: @escaping (([T], T2)) -> Result<Output, Error>,
        onUpdate: @escaping (Result<Output, Error>) -> Void
    ) -> UUID {
        let subscriptionID = UUID()
    
        let collectionPublisher = query.snapshotPublisher()
        let docPublisher = doc.snapshotPublisher()
        
        let combined = collectionPublisher.combineLatest(docPublisher)

        lock.lock()
        defer { lock.unlock() }

        let cancellable = combined
            .map { (collectionSnapshot, docSnapshot) -> Result<([T], T2), Error> in
                // Decode collection -> [T]
                let documents = collectionSnapshot.allDocuments
                var objects = [T]()
                var decodingProblems = [CodingProblem2]()
                for doc in documents {
                    do {
                        objects.append(try doc.data(as: T.self))
                    } catch {
                        decodingProblems.append(CodingProblem2(problemQuerySnapshot: doc, error: error))
                    }
                }

                // Check collection decoding threshold
                let ratio = documents.isEmpty ? 0 : Double(decodingProblems.count) / Double(documents.count)
                let threshold = 0.5
                
                if ratio >= threshold {
                    return .failure(
                        DSError2.CouldNotDecode("Decoding failure ratio for collection: \(ratio)", decodingProblems)
                    )
                }

                // Decode document
                do {
                    let item = try docSnapshot.data(as: T2.self)
                    return .success((objects, item))
                } catch {
                    return .failure(DSError2.CouldNotDecode("Failed to decode document", []))
                }
            }
            .map { result -> Result<Output, Error> in
                switch result {
                case .success(let items):
                    return transformation(items)
                case .failure(let error):
                    return .failure(error)
                }
            }
            .receive(on: DispatchQueue.main)
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

    /// Subscribe to one collection and one document without transformation
    /// - Parameters:
    ///   - query: The collection query
    ///   - doc: Document reference
    ///   - onUpdate: Callback with the collection and document data on the main thread
    /// - Returns: Subscription token that can be used to unsubscribe
    public func subscribeToCollectionAndDocument<
        T: Codable,
        T2: Codable,
        Query: FirestoreQuery
    >(
        query: Query,
        doc: FirestoreDocumentReference,
        onUpdate: @escaping (Result<([T], T2), Error>) -> Void
    ) -> UUID {
        return subscribeToCollectionAndDocument(
            query: query,
            doc: doc,
            transformation: { .success($0) },
            onUpdate: onUpdate
        )
    }

    /// Subscribe to one collection and two documents with transformation
    /// - Parameters:
    ///   - query: The collection query
    ///   - doc1: First document reference
    ///   - doc2: Second document reference
    ///   - transformation: Transformation closure that runs on a background thread
    ///   - onUpdate: Callback with the transformed result on the main thread
    /// - Returns: Subscription token that can be used to unsubscribe
    public func subscribeToCollectionAndTwoDocuments<
        T: Codable,
        T2: Codable,
        T3: Codable,
        Query: FirestoreQuery,
        Output
    >(
        query: Query,
        doc1: FirestoreDocumentReference,
        doc2: FirestoreDocumentReference,
        transformation: @escaping (([T], T2, T3)) -> Result<Output, Error>,
        onUpdate: @escaping (Result<Output, Error>) -> Void
    ) -> UUID {
        let subscriptionID = UUID()
    
        let collectionPublisher = query.snapshotPublisher()
        let doc1Publisher = doc1.snapshotPublisher()
        let doc2Publisher = doc2.snapshotPublisher()
        
        let combined = collectionPublisher.combineLatest(doc1Publisher, doc2Publisher)

        lock.lock()
        defer { lock.unlock() }

        let cancellable = combined
            .map { (collectionSnapshot, doc1Snapshot, doc2Snapshot) -> Result<([T], T2, T3), Error> in
                // Decode collection -> [T]
                let documents = collectionSnapshot.allDocuments
                var objects = [T]()
                var decodingProblems = [CodingProblem2]()
                for doc in documents {
                    do {
                        objects.append(try doc.data(as: T.self))
                    } catch {
                        decodingProblems.append(CodingProblem2(problemQuerySnapshot: doc, error: error))
                    }
                }

                // Check collection decoding threshold
                let ratio = documents.isEmpty ? 0 : Double(decodingProblems.count) / Double(documents.count)
                let threshold = 0.5
                
                if ratio >= threshold {
                    return .failure(
                        DSError2.CouldNotDecode("Decoding failure ratio for collection: \(ratio)", decodingProblems)
                    )
                }

                // Decode documents
                do {
                    let item1 = try doc1Snapshot.data(as: T2.self)
                    let item2 = try doc2Snapshot.data(as: T3.self)
                    
                    return .success((objects, item1, item2))
                } catch {
                    return .failure(DSError2.CouldNotDecode("Failed to decode one or more documents", []))
                }
            }
            .map { result -> Result<Output, Error> in
                switch result {
                case .success(let items):
                    return transformation(items)
                case .failure(let error):
                    return .failure(error)
                }
            }
            .receive(on: DispatchQueue.main)
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

    /// Subscribe to one collection and two documents without transformation
    /// - Parameters:
    ///   - query: The collection query
    ///   - doc1: First document reference
    ///   - doc2: Second document reference
    ///   - onUpdate: Callback with the collection and document data on the main thread
    /// - Returns: Subscription token that can be used to unsubscribe
    public func subscribeToCollectionAndTwoDocuments<
        T: Codable,
        T2: Codable,
        T3: Codable,
        Query: FirestoreQuery
    >(
        query: Query,
        doc1: FirestoreDocumentReference,
        doc2: FirestoreDocumentReference,
        onUpdate: @escaping (Result<([T], T2, T3), Error>) -> Void
    ) -> UUID {
        return subscribeToCollectionAndTwoDocuments(
            query: query,
            doc1: doc1,
            doc2: doc2,
            transformation: { .success($0) },
            onUpdate: onUpdate
        )
    }

    /// Standard unsubscribe
    public func unsubscribe(_ subscriptionID: UUID) {
        lock.lock()
        defer { lock.unlock() }
        cancellables[subscriptionID]?.cancel()
        cancellables.removeValue(forKey: subscriptionID)
        print("unsubscribed \(subscriptionID) from FirestoreSubscriptionListener")
    }
    
    /// Unsubscribe all
    public func unsubscribeAll() {
        lock.lock()
        defer { lock.unlock() }
        cancellables.forEach { $0.value.cancel() }
        cancellables.removeAll()
    }
}
