//
//  Copyright (c) 2018. Uber Technologies
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation

func applyVariableTemplate(name: String,
                           type: Type,
                           typeKeys: [String: String]?,
                           staticKind: String,
                           shouldOverride: Bool,
                           accessControlLevelDescription: String) -> String {

    let underlyingName = "\(String.underlyingVarPrefix)\(name.capitlizeFirstLetter)"
    let underlyingSetCallCount = "\(name)\(String.setCallCountSuffix)"
    let underlyingVarDefaultVal = type.defaultVal(with: typeKeys) ?? ""
    
    var underlyingType = type.typeName
    if underlyingVarDefaultVal.isEmpty {
        underlyingType = type.underlyingType
    }

    let overrideStr = shouldOverride ? "\(String.override) " : ""
    var acl = accessControlLevelDescription
    if !acl.isEmpty {
        acl = acl + " "
    }

    let staticStr = staticKind.isEmpty ? "" : "\(staticKind) "
    let assignVal = underlyingVarDefaultVal.isEmpty ? "" : "= \(underlyingVarDefaultVal)"
    var setCallCountStmt = "\(underlyingSetCallCount) += 1"

    var template = ""
    if !staticKind.isEmpty ||  underlyingVarDefaultVal.isEmpty {
        if staticKind.isEmpty {
            setCallCountStmt = "if \(String.doneInit) { \(underlyingSetCallCount) += 1 }"
        }
        template = """
            \(acl)\(staticStr)var \(underlyingSetCallCount) = 0
            \(staticStr)var \(underlyingName): \(underlyingType) \(assignVal)
            \(acl)\(staticStr)\(overrideStr)var \(name): \(type.typeName) {
                get { return \(underlyingName) }
                set {
                    \(setCallCountStmt)
                    \(underlyingName) = newValue
                }
            }
        """
    } else {
        template = """
            \(acl)var \(underlyingSetCallCount) = 0
            \(acl)\(overrideStr)var \(name): \(type.typeName) \(assignVal) { didSet { \(setCallCountStmt) } }
        """
    }

    return template
}

func applyRxVariableTemplate(name: String,
                             type: Type,
                             typeKeys: [String: String]?,
                             staticKind: String,
                             shouldOverride: Bool,
                             accessControlLevelDescription: String) -> String? {
    let typeName = type.typeName
    if let range = typeName.range(of: String.observableVarPrefix), let lastIdx = typeName.lastIndex(of: ">") {
        let typeParamStr = typeName[range.upperBound..<lastIdx]
        
        let underlyingSubjectName = "\(name)\(String.subjectSuffix)"
//        let whichSubject = "\(underlyingSubjectName)Kind"
        let underlyingSetCallCount = "\(underlyingSubjectName)\(String.setCallCountSuffix)"
        let publishSubjectName = underlyingSubjectName
        let publishSubjectType = "\(String.publishSubject)<\(typeParamStr)>"
//        let behaviorSubjectName = "\(name)\(String.behaviorSubject)"
//        let behaviorSubjectType = "\(String.behaviorSubject)<\(typeParamStr)>"
//        let replaySubjectName = "\(name)\(String.replaySubject)"
//        let replaySubjectType = "\(String.replaySubject)<\(typeParamStr)>"
//        let underlyingObservableName = "\(name)\(String.rx)\(String.subjectSuffix)"
//        let underlyingObservableType = typeName[typeName.startIndex..<typeName.index(after: lastIdx)]
        let acl = accessControlLevelDescription.isEmpty ? "" : accessControlLevelDescription + " "
        let setCallCountStmt = //staticStr.isEmpty ? "if \(String.doneInit) { \(underlyingSetCallCount) += 1 }" :
                                "\(underlyingSetCallCount) += 1"

        let overrideStr = shouldOverride ? "\(String.override) " : ""
        var template = ""

        if staticKind.isEmpty {
            template = """
                \(acl)var \(underlyingSetCallCount) = 0
                \(acl)var \(publishSubjectName) = \(publishSubjectType)() { didSet { \(setCallCountStmt) } }
                \(acl)\(overrideStr)var \(name): \(typeName) = \(publishSubjectType)() { didSet { if let val = \(name) as? \(publishSubjectType) { \(publishSubjectName) =  val } } }
            """
            
        } else {
                template = """
                \(acl)\(staticKind) var \(underlyingSetCallCount) = 0
                \(acl)\(staticKind) var \(publishSubjectName) = \(publishSubjectType)() { didSet { \(setCallCountStmt) } }
                \(acl)\(staticKind) \(overrideStr)var \(name): \(typeName) = \(publishSubjectType)() {
                    get { return \(publishSubjectName) }
                    set { if let val = newValue as? \(publishSubjectType) { \(publishSubjectName) = val } }
                }
            """
        }
        
        return template
    }
    return nil
}

