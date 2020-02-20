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

    let assignVal = underlyingVarDefaultVal.isEmpty ? "" : "= \(underlyingVarDefaultVal)"
    var setCallCountStmt = "\(underlyingSetCallCount) += 1"

    var template = ""
    if !staticKind.isEmpty ||  underlyingVarDefaultVal.isEmpty {
        if staticKind.isEmpty {
            setCallCountStmt = "if \(String.doneInit) { \(underlyingSetCallCount) += 1 }"
        }

        let staticStr = staticKind.isEmpty ? "" : "\(staticKind) "

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
                             overrideTypes: [String: String]?,
                             typeKeys: [String: String]?,
                             staticKind: String,
                             shouldOverride: Bool,
                             accessControlLevelDescription: String) -> String? {
    let typeName = type.typeName
    if let range = typeName.range(of: String.observableVarPrefix), let lastIdx = typeName.lastIndex(of: ">") {
        let typeParamStr = typeName[range.upperBound..<lastIdx]

        var subjectKind = ""
        var underlyingSubjectType = ""
        if let overrideTypes  = overrideTypes {
            if let val = overrideTypes[name] {
                subjectKind = val
            } else if let val = overrideTypes["all"] {
                subjectKind = val
            }
        }
 
        if subjectKind.isEmpty {
            subjectKind = String.publishSubject
        }
        underlyingSubjectType = "\(subjectKind)<\(typeParamStr)>"

        var underlyingSubjectTypeDefaultVal = ""
        if subjectKind == String.publishSubject {
            underlyingSubjectTypeDefaultVal = "\(underlyingSubjectType)()"
        } else if subjectKind == String.replaySubject {
            underlyingSubjectTypeDefaultVal = "\(underlyingSubjectType).create(bufferSize: 1)"
        }
        
        let underlyingSubjectName = "\(name)\(String.subjectSuffix)"
        let underlyingSetCallCount = "\(underlyingSubjectName)\(String.setCallCountSuffix)"
        let defaultValAssignStr = underlyingSubjectTypeDefaultVal.isEmpty ? ": \(underlyingSubjectType)!" : " = \(underlyingSubjectTypeDefaultVal)"

        let acl = accessControlLevelDescription.isEmpty ? "" : accessControlLevelDescription + " "
        let overrideStr = shouldOverride ? "\(String.override) " : ""
        let staticStr = staticKind.isEmpty ? "" : "\(staticKind) "
        let incrementCallCount = "\(underlyingSetCallCount) += 1"
        let setCallCountStmt = staticKind.isEmpty ? "if \(String.doneInit) { \(incrementCallCount) }" : incrementCallCount
        let template = """
                \(acl)\(staticStr)var \(underlyingSetCallCount) = 0
                \(acl)\(staticStr)var \(underlyingSubjectName)\(defaultValAssignStr) { didSet { \(setCallCountStmt) } }
                \(acl)\(staticStr)\(overrideStr)var \(name): \(typeName) {
                    get { return \(underlyingSubjectName) }
                    set { if let val = newValue as? \(underlyingSubjectType) { \(underlyingSubjectName) = val } }
                }
            """

        return template
    }
    return nil
}

