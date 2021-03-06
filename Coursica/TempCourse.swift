//
//  TempCourse.swift
//  Coursica
//
//  Created by Regan Bell on 6/30/15.
//  Copyright (c) 2015 Prestige Worldwide. All rights reserved.
//

import Foundation
import RealmSwift

extension FDataSnapshot {
    
    func snapshotChildren() -> [FDataSnapshot] {
        
        var snapshotChildren: [FDataSnapshot] = []
        for child in self.children {
            let snapshotChild = (child as! FDataSnapshot)
            snapshotChildren.append(snapshotChild)
        }
        return snapshotChildren
    }
}

protocol ListableCourse {
    var number: String { get set }
    var shortField: String { get set }
    var title: String { get set }
    var displayTitle: String { get }
}

class TempCourse: ListableCourse {
    var number: String = ""
    var shortField: String = ""
    var title: String = ""
    var displayTitle: String {
        get {
            return "\(self.shortField) \(self.number): \(self.title)"
        }
    }
    var course: Course? {
        return (try? Realm().objects(Course).filter("number = '\(number)' AND shortField = '\(shortField)'"))?.first
    }
    
    init(CS50Dictionary: NSDictionary) {
        
        if let combined = CS50Dictionary["number"] as? String {
            let halves = combined.componentsSeparatedByString(" ")
            self.shortField = halves.first!
            self.number = halves[1]
        }
        if let title = CS50Dictionary["title"] as? String {
            self.title = title
        }
    }
        
    init(snapshot: FDataSnapshot) {
        for field in snapshot.snapshotChildren() {
            switch field.key {
            case "number":
                self.number = field.value as! String
            case "shortField":
                self.shortField = field.value as! String
            case "title":
                self.title = field.value as! String
            default:
                print("Unexpected course field type\n")
            }
        }
    }
    
    init(course: Course) {
        self.number = course.number
        self.title = course.title
        self.shortField = course.shortField
    }
}