//
//  CodingProblem.swift
//  HealthJournal
//
//  Created by matt naples on 2/23/23.
//

import Foundation
import FirebaseFirestore
//import FirebaseFirestoreSwift
public struct CodingProblem{
    let problemQuerySnapshot: QueryDocumentSnapshot?
    let problemDocumentSnapshot: DocumentSnapshot?
    let error: Error
    public init(problemQuerySnapshot: QueryDocumentSnapshot, error: Error){
        self.problemQuerySnapshot = problemQuerySnapshot
        self.error = error
        self.problemDocumentSnapshot = nil
        
    }
    
    
    public init(problemDocumentSnapshot: DocumentSnapshot, error: Error){
        self.problemDocumentSnapshot = problemDocumentSnapshot
        self.error = error
        self.problemQuerySnapshot = nil
    }
}
