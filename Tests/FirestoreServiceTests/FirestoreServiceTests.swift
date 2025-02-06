import XCTest
@testable import FirestoreService
import Foundation
import Combine
 // Where your protocols & manager live


final class FirestoreSubscriptionManagerTests: XCTestCase {

    private var subscriptionManager: FirestoreSubscriptionManager<MockModel,MockFirestoreCollection>!
    private var mockCollection: MockFirestoreCollection!
    private var mockQuery: MockFirestoreQuery!

    override func setUp() {
        super.setUp()
        mockQuery = MockFirestoreQuery()
        mockCollection = MockFirestoreCollection(mockQuery: mockQuery)
        subscriptionManager = FirestoreSubscriptionManager(collection: mockCollection)
    }

    override func tearDown() {
        subscriptionManager.unsubscribeAll()
        super.tearDown()
    }

    func testMultipleClientsReceiveUpdates() {
        let expectation1 = XCTestExpectation(description: "Client 1 should receive updates")
        let expectation2 = XCTestExpectation(description: "Client 2 should receive updates")

        var client1ReceivedItems: [MockModel] = []
        var client2ReceivedItems: [MockModel] = []

        // Client 1 subscribes
        subscriptionManager.subscribe(to: {$0.asQuery().}, <#T##(Result<[T], Error>) -> Void#>)
        subscriptionManager.subscribe { result in
            if case let .success(items) = result {
                client1ReceivedItems = items
                expectation1.fulfill()
            }
        }

        // Client 2 subscribes
        subscriptionManager.subscribe { result in
            if case let .success(items) = result {
                client2ReceivedItems = items
                expectation2.fulfill()
            }
        }

        // Mock snapshot
        let mockDoc1 = MockDocumentSnapshot(data: .init(id: "doc1", value: 100))
        let mockDoc2 = MockDocumentSnapshot(data: .init(id: "doc2", value: 200))
        let snapshot = MockQuerySnapshot(documents: [mockDoc1, mockDoc2])

        // Send snapshot
        mockQuery.send(snapshot: snapshot)

        wait(for: [expectation1, expectation2], timeout: 2.0)

        XCTAssertEqual(client1ReceivedItems.count, 2, "Client 1 should receive 2 items")
        XCTAssertEqual(client2ReceivedItems.count, 2, "Client 2 should receive 2 items")
    }

    func testUnsubscriptionStopsReceivingUpdates() {
        let expectation1 = XCTestExpectation(description: "Client 1 should stop receiving updates")
        expectation1.isInverted = true // Expectation should not be fulfilled

        // Client 1 subscribes
        let token = subscriptionManager.subscribe { result in
            if case .success = result {
                expectation1.fulfill()
            }
        }

        // Unsubscribe Client 1
        subscriptionManager.unsubscribe(token)

        // Mock snapshot
        let mockDoc1 = MockDocumentSnapshot(data: .init(id: "doc1", value: 100))
        let snapshot = MockQuerySnapshot(documents: [mockDoc1])

        // Send snapshot
        mockQuery.send(snapshot: snapshot)

        wait(for: [expectation1], timeout: 1.0)
    }

    func testUnsubscribeAllStopsAllClients() {
        let expectation1 = XCTestExpectation(description: "Client 1 should stop receiving updates")
        expectation1.isInverted = true
        let expectation2 = XCTestExpectation(description: "Client 2 should stop receiving updates")
        expectation2.isInverted = true

        // Client 1 subscribes
        let _ = subscriptionManager.subscribe { result in
            if case .success = result {
                expectation1.fulfill()
            }
        }

        // Client 2 subscribes
        let _ = subscriptionManager.subscribe { result in
            if case .success = result {
                expectation2.fulfill()
            }
        }

        // Unsubscribe all
        subscriptionManager.unsubscribeAll()

        // Mock snapshot
        let mockDoc1 = MockDocumentSnapshot(data: .init(id: "doc1", value: 100))
        let snapshot = MockQuerySnapshot(documents: [mockDoc1])

        // Send snapshot
        mockQuery.send(snapshot: snapshot)

        wait(for: [expectation1, expectation2], timeout: 1.0)
    }
    func testUnsubscribingOneClientStopsOnlyThatClient() {
        let expectation1 = XCTestExpectation(description: "Client 1 should stop receiving updates")
        expectation1.isInverted = true // Client 1 should not receive updates
        let expectation2 = XCTestExpectation(description: "Client 2 should continue receiving updates")

        var client2ReceivedItems: [MockModel] = []

        // Client 1 subscribes
        let token1 = subscriptionManager.subscribe { result in
            if case .success = result {
                expectation1.fulfill()
            }
        }

        // Client 2 subscribes
        let token2 = subscriptionManager.subscribe { result in
            if case let .success(items) = result {
                client2ReceivedItems = items
                expectation2.fulfill()
            }
        }

        // Unsubscribe Client 1
        subscriptionManager.unsubscribe(token1)

        // Mock snapshot
        let mockDoc1 = MockDocumentSnapshot(data: .init(id: "doc1", value: 100))
        let snapshot = MockQuerySnapshot(documents: [mockDoc1])

        // Send snapshot
        mockQuery.send(snapshot: snapshot)

        wait(for: [expectation1, expectation2], timeout: 2.0)

        XCTAssertEqual(client2ReceivedItems.count, 1, "Client 2 should have received 1 item")
        
    }

    func testUnsubscribingSomeClientsStopsOnlyThoseClients() {
        let expectation1 = XCTestExpectation(description: "Client 1 should stop receiving updates")
        expectation1.isInverted = true // Client 1 should not receive updates
        let expectation2 = XCTestExpectation(description: "Client 2 should continue receiving updates")
        let expectation3 = XCTestExpectation(description: "Client 3 should continue receiving updates")

        var client2ReceivedItems: [MockModel] = []
        var client3ReceivedItems: [MockModel] = []

        // Client 1 subscribes
        let token1 = subscriptionManager.subscribe { result in
            if case .success = result {
                expectation1.fulfill()
            }
        }

        // Client 2 subscribes
        let token2 = subscriptionManager.subscribe { result in
            if case let .success(items) = result {
                client2ReceivedItems = items
                expectation2.fulfill()
            }
        }
        
        // Client 3 subscribes
        let token3 = subscriptionManager.subscribe { result in
            if case let .success(items) = result {
                client3ReceivedItems = items
                expectation3.fulfill()
            }
        }

        // Unsubscribe Client 1
        subscriptionManager.unsubscribe(token1)

        // Mock snapshot
        let mockDoc1 = MockDocumentSnapshot(data: .init(id: "doc1", value: 100))
        let snapshot = MockQuerySnapshot(documents: [mockDoc1])

        // Send snapshot
        mockQuery.send(snapshot: snapshot)

        wait(for: [expectation1, expectation2, expectation3], timeout: 2.0)

        XCTAssertEqual(client2ReceivedItems.count, 1, "Client 2 should have received 1 item")
        XCTAssertEqual(client3ReceivedItems.count, 1, "Client 3 should have received 1 item")
    }

  
}
