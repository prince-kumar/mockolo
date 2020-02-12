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
    let staticStr = staticKind.isEmpty ? "" : "\(staticKind) "
    let setCallCountStmt = staticStr.isEmpty ? "if \(String.doneInit) { \(underlyingSetCallCount) += 1 }" : "\(underlyingSetCallCount) += 1"

    let overrideStr = shouldOverride ? "\(String.override) " : ""
    var acl = accessControlLevelDescription
    if !acl.isEmpty {
        acl = acl + " "
    }

    let template = """
    
    \(acl)\(staticStr)var \(underlyingSetCallCount) = 0
    \(staticStr)var \(underlyingName): \(underlyingType) \(underlyingVarDefaultVal.isEmpty ? "" : "= \(underlyingVarDefaultVal)")
    \(acl)\(staticStr)\(overrideStr)var \(name): \(type.typeName) {
        get { return \(underlyingName) }
        set {
            \(underlyingName) = newValue
            \(setCallCountStmt)
        }
    }
"""
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
        let staticStr = staticKind.isEmpty ? "" : "\(staticKind) "
        let setCallCountStmt = staticStr.isEmpty ? "if \(String.doneInit) { \(underlyingSetCallCount) += 1 }" : "\(underlyingSetCallCount) += 1"

        let overrideStr = shouldOverride ? "\(String.override) " : ""
        
        let template = """
        
        \(acl)\(staticStr)var \(underlyingSetCallCount) = 0
        \(acl)\(staticStr)var \(publishSubjectName) = \(publishSubjectType)() { didSet { \(setCallCountStmt) } }
        \(acl)\(staticStr)\(overrideStr)var \(name): \(typeName) {
            get {
                return \(publishSubjectName)
            }
            set {
                if let val = newValue as? \(publishSubjectType) {
                    \(publishSubjectName) = val
                }
            }
        }
    """
        return template
    }
    return nil
}
