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

    /// Subscribe to a single collection, specifying `T` and `FCollection` at the method level
    public func subscribe<T: Codable>(
        query: FirestoreQuery,
        onUpdate: @escaping (Result<[T], Error>) -> Void
    ) -> UUID {
        let subscriptionID = UUID()
        let publisher = query.snapshotPublisher()

        lock.lock()
        defer { lock.unlock() }

        let cancellable = publisher
            .sink(
                receiveCompletion: { completion in
                    if case let .failure(error) = completion {
                        onUpdate(.failure(error))
                    }
                },
                receiveValue: { snapshot in
                    let documents = snapshot.allDocuments
                    var resultingObjects = [T]()
                    var decodingProblems = [CodingProblem2]() // same struct you defined earlier

                    for doc in documents {
                        do {
                            let obj = try doc.data(as: T.self)
                            resultingObjects.append(obj)
                        } catch {
                            decodingProblems.append(CodingProblem2(problemQuerySnapshot: doc, error: error))
                        }
                    }

                    // Example threshold logic:
                    guard documents.isEmpty ||
                          (Double(decodingProblems.count) / Double(documents.count)
                           < 0.5 /* or your threshold */) else {
                        let ratio = Double(decodingProblems.count) / Double(documents.count)
                        onUpdate(.failure(
                            DSError2.CouldNotDecode(
                                "\(ratio * 100)% of the docs failed to decode.", decodingProblems
                            )
                        ))
                        return
                    }

                    onUpdate(.success(resultingObjects))
                }
            )

        cancellables[subscriptionID] = cancellable
        return subscriptionID
    }

    /// Subscribe to two collections simultaneously, with separate `T` and `T2` types, and separate `FCollection` types
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
        
        let subscriptionID = UUID()
    
        let publisher1 = query1.snapshotPublisher()
        let publisher2 = query2.snapshotPublisher()
        
        let combined = publisher1.combineLatest(publisher2)

        lock.lock()
        defer { lock.unlock() }

        let cancellable = combined
            .sink(receiveCompletion: { completion in
                if case let .failure(error) = completion {
                    onUpdate(.failure(error))
                }
            }, receiveValue: { (snapshot1, snapshot2) in
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
                    onUpdate(.failure(
                        DSError2.CouldNotDecode("Decoding failure ratio for first query: \(ratio1)", decodingProblems1)
                    ))
                    return
                }
                if ratio2 >= threshold {
                    onUpdate(.failure(
                        DSError2.CouldNotDecode("Decoding failure ratio for second query: \(ratio2)", decodingProblems2)
                    ))
                    return
                }

                // Success with both arrays
                onUpdate(.success((objects1, objects2)))
            })
        
        cancellables[subscriptionID] = cancellable
        return subscriptionID
    }

    /// Subscribe to three collections simultaneously, with separate `T`, `T2`, and `T3` types, and separate `FCollection` types
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
        let subscriptionID = UUID()
    
        let publisher1 = query1.snapshotPublisher()
        let publisher2 = query2.snapshotPublisher()
        let publisher3 = query3.snapshotPublisher()
        
        let combined = publisher1.combineLatest(publisher2, publisher3)

        lock.lock()
        defer { lock.unlock() }

        let cancellable = combined
            .sink(receiveCompletion: { completion in
                if case let .failure(error) = completion {
                    onUpdate(.failure(error))
                }
            }, receiveValue: { (snapshot1, snapshot2, snapshot3) in
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
                    onUpdate(.failure(
                        DSError2.CouldNotDecode("Decoding failure ratio for first query: \(ratio1)", decodingProblems1)
                    ))
                    return
                }
                if ratio2 >= threshold {
                    onUpdate(.failure(
                        DSError2.CouldNotDecode("Decoding failure ratio for second query: \(ratio2)", decodingProblems2)
                    ))
                    return
                }
                if ratio3 >= threshold {
                    onUpdate(.failure(
                        DSError2.CouldNotDecode("Decoding failure ratio for third query: \(ratio3)", decodingProblems3)
                    ))
                    return
                }

                // Success with all three arrays
                onUpdate(.success((objects1, objects2, objects3)))
            })
        
        cancellables[subscriptionID] = cancellable
        return subscriptionID
    }

    /// Standard unsubscribe
    public func unsubscribe(_ subscriptionID: UUID) {
        lock.lock()
        defer { lock.unlock() }
        cancellables[subscriptionID]?.cancel()
        cancellables.removeValue(forKey: subscriptionID)
    }
    
    /// Unsubscribe all
    public func unsubscribeAll() {
        lock.lock()
        defer { lock.unlock() }
        cancellables.forEach { $0.value.cancel() }
        cancellables.removeAll()
    }
}
