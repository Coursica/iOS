//
//  AppDelegate.swift
//  Coursica
//
//  Created by Regan Bell on 7/18/15.
//  Copyright (c) 2015 Prestige Worldwide. All rights reserved.
//

import UIKit
import RealmSwift
import Fabric
import Crashlytics

class Key {
    var term: String = ""
    var year: String = ""
    var string: String { return "\(self.term)\(self.year)" }
    init(string: String) {
        self.year = NSRegularExpression(pattern: "[0-9]+")?.firstMatchInWholeString(string) ?? ""
        self.term = string.stringByReplacingOccurrencesOfString(self.year, withString: "")
    }
    class func compare(a: Key, b: Key) -> Key {
        switch a.year.caseInsensitiveCompare(b.year) {
        case .OrderedAscending: //a = 2012, b = 2013
            return b
        case .OrderedDescending: //a = 2013, b = 2012
            return a
        case .OrderedSame:
            if a.term == "fall" {
                return a
            } else {
                return b
            }
        }
    }
}

extension String {
    
    var firebaseForbidden: [String] { return [".", "#", "$", "/", "[", "]"] }
    
    var asFirebaseKey: String {
        var string = self
        for (i, forbidden) in firebaseForbidden.enumerate() {
            string = string.stringByReplacingOccurrencesOfString(forbidden, withString: "&\(i)&")
        }
        return string
    }
    
    var decodedFirebaseKey: String {
        var string = self
        for (i, forbidden) in firebaseForbidden.enumerate() {
            string = string.stringByReplacingOccurrencesOfString("&\(i)&", withString: forbidden)
        }
        return string
    }
}

class SizeRange {
    
    var start: Int
    var end: Int
    var scores: [Double] = []
    init(start: Int, end: Int) {
        self.start = start
        self.end = end
    }
    func contains(n: Int) -> Bool { return n >= start && n <= end }
}

@available(iOS 9.0, *)
@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    var allGroupScores: Dictionary<String, [Double]>!
    var allScores: [Double]!
    let range = Range<Int>(start: 0, end: 10)
    var allSizeScores: [SizeRange] =
        [SizeRange(start: 1, end: 10),
         SizeRange(start: 11, end: 25),
         SizeRange(start: 26, end: 50),
         SizeRange(start: 51, end: 100),
         SizeRange(start: 101, end: 200),
         SizeRange(start: 201, end: 500),
         SizeRange(start: 501, end: 10000)]
    var facultyScores: [String: [Double]] = Dictionary<String, [Double]>()
    var facultyAverages: [String: Double] = Dictionary<String, Double>()
    var realm: Realm!
    
    func coursesJSONFromDisk() -> NSDictionary {
        let data = NSData(contentsOfFile: NSBundle.mainBundle().pathForResource("final_results copy", ofType: "json")!)!
        return (try! NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions())) as! NSDictionary
    }
    
    func calculatePercentiles(courses: Results<Course>) {
        allGroupScores = Dictionary<String, [Double]>()
        allScores = []
        for course in courses {
            if course.overall != 0 {
                allScores.append(course.overall)
                var groupScores = allGroupScores[course.shortField] ?? []
                groupScores.append(course.overall)
                allGroupScores.updateValue(groupScores, forKey: course.shortField)
                if course.enrollment != 0 {
                    for range in allSizeScores {
                        if range.contains(course.enrollment) {
                            range.scores.append(course.overall)
                            break
                        }
                   }
                }
            }
        }
        allScores = allScores.sort(<)
        var sortedGroupScores = Dictionary<String, [Double]>()
        for (group, array) in allGroupScores {
            sortedGroupScores[group] = array.sort(<)
        }
        allGroupScores = sortedGroupScores
        for range in allSizeScores {
            range.scores.sortInPlace(<)
        }
    }
    
    func arrayForGraphTab(tab: GraphViewTab, course: Course) -> [Double] {
        switch tab {
        case .All:    return self.allScores
        case .Group:  return self.allGroupScores[course.shortField]!
        case .Size:
            for range in self.allSizeScores {
                if range.contains(course.enrollment) {return range.scores}
            }
        }
        return []
    }
    
    func savePercentilesOnCourses(courses: Results<Course>) {
        for course in courses {
            if course.overall < 0.1 {
                course.percentileAll = -1
                course.percentileGroup = -1
                course.percentileSize = -1
                continue
            }
            let tabs: [GraphViewTab] = [.All, .Group, .Size]
            for tab in tabs {
                let sortedScores = arrayForGraphTab(tab, course: course)
                let index = sortedScores.indexOf(course.overall)!
                let percentile = Double(index) / Double(sortedScores.count)
                let percentileInt = Int(percentile * 100)
                switch tab {
                case .All: course.percentileAll = percentileInt
                case .Group: course.percentileGroup = percentileInt
                case .Size: course.percentileSize = percentileInt
                }
            }
        }
    }
    
    func extractQData() {
        let json = coursesJSONFromDisk()
        var courseDict: [String: Course] = Dictionary<String,Course>()
        let courses = try! Realm().objects(Course)
        if courses.count != 0 {
            for course in courses {
                courseDict[course.display.serverTitle] = course
            }
            try! Realm().write {
                for (key, value) in json {
                    var mostRecent = Key(string: "fall1870")
                    for (id, _) in (value as! NSDictionary) {
                        mostRecent = Key.compare(Key(string: id as! String), b: mostRecent)
                    }
                    let mostRecentReport = (value as! NSDictionary)[mostRecent.string] as! NSDictionary
                    let report = ReportParser.reportFromDictionary(mostRecentReport)
                    for faculty in report!.facultyReports {
                        for response in faculty.responses {
                            if let scores = self.facultyScores[response.question] {
                                self.facultyScores[response.question] = scores + [response.mean]
                            } else {
                                self.facultyScores[response.question] = [response.mean]
                            }
                        }
                    }
                    
                    if let course = courseDict[(key as! String)] {
                        if let enrollmentString = mostRecentReport["enrollment"] as? NSString {
                            course.enrollment = enrollmentString.integerValue
                            course.enrollmentSource = mostRecent.string
                        }

                        if let responses = mostRecentReport["responses"] as? NSDictionary {
                            if let overall = responses["Course Overall"] as? NSDictionary {
                                if let meanString = overall["mean"] as? NSNumber {
                                    course.overall = meanString.doubleValue
                                }
                            }
                            if let workload = responses["Workload (hours per week)"] as? NSDictionary {
                                if let meanString = workload["mean"] as? NSNumber {
                                    course.workload = meanString.doubleValue
                                }
                            }
                        }
                    }
                }
                
                for (question, scores) in self.facultyScores {
                    let average = FacultyAverage()
                    average.question = question
                    average.score = scores.reduce(0.0, combine: +) / Double(scores.count)
                    try! Realm().add(average, update: false)
                }
            }
        }
    }

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject : AnyObject]?) -> Bool {

        let window = UIWindow(frame: UIScreen.mainScreen().bounds)
        let navigationController = NavigationController(rootViewController: CoursesViewController())
        window.rootViewController = navigationController
        window.makeKeyAndVisible()
        self.window = window
        if !NSUserDefaults.standardUserDefaults().boolForKey("loggedIn") {
            let loginController = UIStoryboard(name: "Main", bundle: nil).instantiateViewControllerWithIdentifier("loginController") as! LoginViewController
            loginController.delegate = self
            navigationController.presentViewController(loginController, animated: false, completion: nil)
        }
        return true
    }
}

@available(iOS 9.0, *)
extension AppDelegate: LoginViewControllerDelegate {
    
    func userDidLoginWithHUID(HUID: String) {
        let defaults = NSUserDefaults.standardUserDefaults()
        defaults.setObject(HUID, forKey: "huid")
        defaults.setBool(true, forKey: "loggedIn")
    }
}
