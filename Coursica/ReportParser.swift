//
//  ReportParser.swift
//  Coursica
//
//  Created by Regan Bell on 7/24/15.
//  Copyright (c) 2015 Prestige Worldwide. All rights reserved.
//

import UIKit

class ReportParser: NSObject {
    class func reportFromSnapshot(snapshot: FDataSnapshot) -> Report? {
        
        if snapshot.value is NSNull {
            return nil
        } else {
            return self.reportFromDictionary(snapshot.value.allValues.first! as! NSDictionary)
        }
    }
    
    class func reportFromDictionary(reportDictionary: NSDictionary) -> Report? {
        
        let report = Report()
        report.setFieldsWithList(["term", "year"], data: reportDictionary)
        if let comments = reportDictionary["comments"] as? NSArray {
            var reportComments: [String] = []
            for entry in comments {
                if let comment = entry as? String {
                    reportComments.append(comment)
                }
            }
            report.comments = reportComments
        }
        if let enrollment = reportDictionary["enrollment"] as? Int {
            report.enrollment = enrollment
        }
        if let responses = reportDictionary["responses"] as? NSDictionary {
            for (key, value) in responses {
                if let responseDict = (value as? NSDictionary) {
                    if let question = key as? String {
                        let response = ResponseParser.responseFromDictionary(responseDict)
                        response.question = question
                        report.responses.append(response)
                    }
                }
            }
        }
        if let facultyReports = reportDictionary["faculty"] as? NSDictionary {
            for (key, value) in facultyReports {
                if let facultyDict = (value as? NSDictionary) {
                    let facultyReport = FacultyReportParser.facultyReportFromDictionary(facultyDict)
                    facultyReport.name = key as! String
                    report.facultyReports.append(facultyReport)
                }
            }
        }
        return report
    }
}
