//
//  Query+Extensions.swift
//  HealthJournal
//
//  Created by matt naples on 8/1/23.
//

import Foundation
import FirebaseFirestore
extension Query {
    func whereField(_ field: String, isDateInToday value: Date) -> Query {
        guard let end = Calendar.current.date(byAdding: .day, value: 1, to: value) else{
            fatalError("could not calculate start date from end date")
        }
        
//        print("start: \(start)")
//        print("end: \(end)")
        return self.whereFieldIsBetween(field, startDate: value, endDate: end)
    }
    func whereFieldIsBetween(_ field: String, startDate: Date, endDate: Date) -> Query{
        let startComponents = Calendar.current.dateComponents([.year, .month, .day], from: startDate)
        let endComponents = Calendar.current.dateComponents([.year, .month, .day], from: endDate)

        guard
            let start = Calendar.current.date(from: startComponents),
            let end = Calendar.current.date(from: endComponents)
        else {
            fatalError("Could not find start date or calculate end date.")
        }
//        print("start: \(start)")
//        print("end: \(end)")
        return self.whereField(field, isGreaterThan: start).whereField(field, isLessThan: end)
    }
}
