//
//  File.swift
//  Coursica
//
//  Created by Regan Bell on 7/14/15.
//  Copyright (c) 2015 Prestige Worldwide. All rights reserved.
//

import RealmSwift

let stopWords: Set<String> =  ["I","a","about","an","are","as","at","be","by","com","for","from","how","in","is","it","of","on","or","that","the","this","to","was","what","when","where","who","will","with","the","www"]

enum IndexType: String {
    case Title = "Title"
    case Field = "Field"
    case Number = "Number"
    case Faculty = "Faculty"
}

struct SearchHit: CustomStringConvertible {
    var term = ""
    var course: Course?
    var scoreAdd = 0.0
    var index = ""
    var description : String {
        return "\nin \(index) \"\(term)\" \(course!.title) \(scoreAdd)"
    }
}

extension NSRegularExpression {
    
    convenience init?(pattern: String) {
        try! self.init(pattern: pattern, options: NSRegularExpressionOptions())
    }
    
    func firstMatchInWholeString(string: String) -> String? {
        let matches = matchesInString(string, options: NSMatchingOptions(), range: NSMakeRange(0, string.characters.count))
        if let first = matches.first {
            return (string as NSString).substringWithRange(first.range)
        }
        return nil
    }
}

class Search: NSObject {
    
    static let shared = Search()
    var results: [SearchHit] = []
    var courseCount = 0.0
    var titleIndex = Index(type: .Title)
    var fieldIndex = Index(type: .Field)
    var numberIndex = Index(type: .Number)
    var facultyIndex = Index(type: .Faculty)
    var _commonAbbreviations: [String: String]? = nil
    var commonAbbreviations: [String: String] {
        if _commonAbbreviations == nil {
            var abbreviations: [String: String] = Dictionary<String, String>()
            let shortFieldPath = NSBundle.mainBundle().pathForResource("ShortFields", ofType: "")
            let rawShortFields = try? NSString(contentsOfFile: shortFieldPath!, encoding: NSUTF8StringEncoding)
            let longFieldPath = NSBundle.mainBundle().pathForResource("LongFields", ofType: "")
            let rawLongFields = try? NSString(contentsOfFile: longFieldPath!, encoding: NSUTF8StringEncoding)
            let shortFields = rawShortFields!.componentsSeparatedByString(",\n")
            let longFields = rawLongFields!.componentsSeparatedByString(",\n")
            for (index, longField) in longFields.enumerate() {
                let shortField = shortFields[index] 
                abbreviations[shortField.lowercaseString] = longField.lowercaseString;
            }
            let common =   ["cs":    "computer science",
                            "ec":    "economics",
                            "cb":    "culture and belief",
                            "ai":    "aesthetic and interpretive understanding",
                            "aiu":   "aesthetic and interpretive understanding",
                            "am":    "applied math",
                            "astro": "astronomy",
                            "bio":   "biology",
                            "lit":   "literature",
                            "comp":  "computer comparative",
                            "sci":   "science",
                            "em":    "empirical and mathematical reasoning",
                            "eps":   "earth and planetary sciences",
                            "es":    "engineering sciences",
                            "er":    "ethical reasoning",
                            "pol":   "policy politics",
                            "hum":   "humanities",
                            "hist":  "history",
                            "kor":   "korean",
                            "lat":   "latin",
                            "med":   "medical",
                            "stats": "statistics",
                            "sls":   "science of living systems",
                            "spu":   "science of the physical universe",
                            "syst":  "systems",
                            "usw":   "united states in the world",
                            "ls":    "life sciences"]
            for (key, value) in common {
                abbreviations[key] = value
            }
            _commonAbbreviations = abbreviations
        }
        return _commonAbbreviations!
    }
    var _longFields: [String]? = nil
    var longFields: [String] {
        if _longFields == nil {
            let longFieldPath = NSBundle.mainBundle().pathForResource("LongFields", ofType: "")
            let rawLongFields = try? NSString(contentsOfFile: longFieldPath!, encoding: NSUTF8StringEncoding)
            let longFields = rawLongFields!.componentsSeparatedByString(",\n")
            _longFields = longFields.map({field in return field.lowercaseString})
        }
        return _longFields!
    }
    
    func buildIndex(courses: Results<Course>) {
        courseCount = Double(courses.count)
        for course in courses {
            titleIndex.addField(course.title, fromCourse: course)
            fieldIndex.addField(course.longField, fromCourse: course)
            let integerString = "\(course.integerNumber)"
            if course.integerNumber > 0 && integerString != course.number {
                numberIndex.addField(integerString, fromCourse: course)
            }
            numberIndex.addField(course.number, fromCourse: course)
            for faculty in course.faculty {
                facultyIndex.addField(faculty.fullName, fromCourse: course)
            }
        }
        for index in [titleIndex, fieldIndex, numberIndex, facultyIndex] {
            index.calculateIDFs(courses.count)
        }
    }
    
    func assignScoresForSearch(search: String) {
        
        let HUID = NSUserDefaults.standardUserDefaults().objectForKey("huid") as! String
        let firebaseRoot: Firebase = Firebase(url: "glaring-heat-9505.firebaseIO.com/searches/\(HUID)/")
        let searchRef = firebaseRoot.childByAutoId()
        searchRef.setValue(search)
        
        if let courses = try? Realm().objects(Course) where titleIndex.terms.count == 0 {
            buildIndex(courses)
        }
        clearSearchScores()
        let searchTerms = explodeSearch(search)
        //TODO: do a weaker match for word stems using NSLinguisticTagger
        results  = []
        var weights: [(Index, Double)]
        if let _ = NSRegularExpression(pattern: "[0-9]+")?.firstMatchInWholeString(search) {
            weights = [(titleIndex, 0.3), (fieldIndex, 0.6), (numberIndex, 0.6), (facultyIndex, 0.3)]
        } else {
            weights = [(titleIndex, 0.3), (fieldIndex, 0.3), (numberIndex, 0.3), (facultyIndex, 0.3)]
        }
        try! Realm().write { () -> Void in
            for (index, weight) in weights {
                self.searchIndex(index, terms: searchTerms, zoneWeight: weight)
            }
            //Debug search with:
//            println(self.results)
        }
    }
    
    func searchIndex(index: Index, terms: [String], zoneWeight: Double) {
        for term in terms {
            if let entry = index.terms[term.lowercaseString] {
                let maxIDF = log(self.courseCount / 1.0)
                let normalizeFactor = 1.0 / maxIDF
                let normalizedScore = entry.idf * normalizeFactor
                let zonedScore = zoneWeight * normalizedScore
                for course in entry.courses {
                    course.searchScore += zonedScore
                    results.append(SearchHit(term: term, course: course, scoreAdd: zonedScore, index: index.type.rawValue))
                }
            }
        }
    }
    
    func explodeSearch(search: String) -> [String] {
        var searchTerms = search.componentsSeparatedByString(" ")
        var count = searchTerms.count;
        var index: Int
        for index = 0; index < count; index++ {
            let term = searchTerms[index]
            if let squish = NSRegularExpression(pattern: "[a-zA-Z]+[0-9]+")?.firstMatchInWholeString(term) {
                let word = NSRegularExpression(pattern: "[a-zA-Z]+")!.firstMatchInWholeString(squish)
                let rest = term.stringByReplacingOccurrencesOfString(word!, withString: "")
                searchTerms.removeAtIndex(index)
                searchTerms.appendContentsOf([word!, rest])
                count++
                index--
            }
            if let expansion = self.commonAbbreviations[term.lowercaseString] {
                let newTerms = expansion.componentsSeparatedByString(" ")
                searchTerms.removeAtIndex(index)
                count--
                for newTerm in newTerms {
                    searchTerms.insert(newTerm, atIndex: index)
                    index++
                    count++
                }
            }
        }
        return searchTerms
    }
    
    func clearSearchScores() {
        if let courses = try? Realm().objects(Course) {
            try? Realm().write {
                for course in courses {
                    course.searchScore = 0
                }
            }
        }
    }
}
