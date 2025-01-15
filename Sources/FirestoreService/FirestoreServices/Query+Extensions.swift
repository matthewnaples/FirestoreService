//
//  Query+Extensions.swift
//  HealthJournal
//
//  Created by matt naples on 8/1/23.
//

import Foundation
import FirebaseFirestore


public extension Query {
    func whereField(_ field: String, isDateInToday value: Date) -> Query {
        guard let end = Calendar.current.date(byAdding: .day, value: 1, to: value) else{
            fatalError("could not calculate start date from end date")
        }
        
//        print("start: \(start)")
//        print("end: \(end)")
        return self.whereFieldIsBetween(field, startDate: value, endDate: end)
    }
    
    /// will include all entries that are ≥ start and ≤ end (inclusive both ends)
    func whereFieldIsBetween(_ field: String, startDate: Date, endDate: Date) -> Query {
        let calendar = Calendar.current

        // Get start date truncated to the beginning of the day
         let start = calendar.startOfDay(for: startDate)

        // Get end date as midnight of the next day
        guard let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate)) else {
            fatalError("Could not calculate end date.")
        }

        return self
            .whereField(field, isGreaterThanOrEqualTo: start)
            .whereField(field, isLessThan: end)
    }

    func whereFieldIsOnOrAfter(_ field: String, date: Date) -> Query{
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)

        guard
            let finalDate = Calendar.current.date(from: components)
        else {
            fatalError("Could not find start date or calculate end date.")
        }
        return self.whereField(field, isGreaterThanOrEqualTo: finalDate)
    }
    func whereFieldIsOnOrBefore(_ field: String, date: Date) -> Query{
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)

        guard
            let finalDate = Calendar.current.date(from: components)
        else {
            fatalError("Could not find date or calculate end date.")
        }
        return self.whereField(field, isLessThanOrEqualTo: finalDate)
    }
}
