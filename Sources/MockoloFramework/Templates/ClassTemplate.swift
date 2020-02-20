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

func applyClassTemplate(name: String,
                        identifier: String,
                        typeKeys: [String: String]?,
                        accessControlLevelDescription: String,
                        attribute: String,
                        declType: DeclType,
                        typealiasWhitelist: [String: [String]]?,
                        initParamCandidates: [Model],
                        declaredInits: [MethodModel],
                        entities: [(String, Model)]) -> String {
    
    let extraInits = extraInitsIfNeeded(initParamCandidates: initParamCandidates, declaredInits: declaredInits,  accessControlLevelDescription: accessControlLevelDescription, declType: declType, typeKeys: typeKeys)
    
    let renderedEntities = entities
        .compactMap { (uniqueId: String, model: Model) -> (String, Int64)? in
            if model.modelType == .typeAlias, let _ = typealiasWhitelist?[model.name] {
                // this case will be handlded by typealiasWhitelist look up later
                return nil
            }
            if model.modelType == .variable, (model.name == String.doneInit || model.name == String.hasBlankInit ){
                return nil
            }
            if let ret = model.render(with: uniqueId, typeKeys: typeKeys) {
                return (ret, model.offset)
            }
            return nil
    }
    .sorted { (left: (String, Int64), right: (String, Int64)) -> Bool in
        if left.1 == right.1 {
            return left.0 < right.0
        }
        return left.1 < right.1
    }
    .map {$0.0}
    .joined(separator: "\n")
    
    var typealiasTemplate = ""
    if let typealiasWhitelist = typealiasWhitelist {
        typealiasTemplate = typealiasWhitelist.map { (arg: (key: String, value: [String])) -> String in
            let joinedType = arg.value.sorted().joined(separator: " & ")
            return  "\(String.typealias) \(arg.key) = \(joinedType)"
        }.joined(separator: "\n")
    }
    
    let template =
    """
    \(attribute)
    \(accessControlLevelDescription)class \(name): \(identifier) {
        \(typealiasTemplate)
        \(extraInits)
        \(renderedEntities)
    }
    """
    
    return template
}

private func extraInitsIfNeeded(initParamCandidates: [Model],
                                declaredInits: [MethodModel],
                                accessControlLevelDescription: String,
                                declType: DeclType,
                                typeKeys: [String: String]?) -> String {
    
    let declaredInitParamsPerInit = declaredInits.map { $0.params }
    
    var needParamedInit = false
    var needBlankInit = false

    if declaredInits.isEmpty, initParamCandidates.isEmpty {
        needBlankInit = true
        needParamedInit = false
    } else {
        if declType == .protocolType {
            let needExtra1 = declaredInitParamsPerInit.isEmpty && !initParamCandidates.isEmpty
            var needExtra2 = false

            let buffer = initParamCandidates.sorted(path: \.fullName, fallback: \.name)
            for paramList in declaredInitParamsPerInit {
                let list = paramList.sorted(path: \.fullName, fallback: \.name)
                if list.count == buffer.count {
                    let diffs = zip(list, buffer).filter {$0.0.fullName != $0.1.fullName}
                    if !diffs.isEmpty {
                        needExtra2 = true
                        break
                    }
                }
            }
            needParamedInit = needExtra1 || needExtra2
            needBlankInit = needParamedInit
        }
    }

    var hasBlankInit = needBlankInit
    var initTemplate = ""
    if needParamedInit {
        var paramsAssign = ""
        var paramsHaveDefaultVals = true
        let params = initParamCandidates
            .map { (element: Model) -> String in
                if let val =  element.type.defaultVal(with: typeKeys, isInitParam: true) {
                    return "\(element.name): \(element.type.typeName) = \(val)"
                }
                var prefix = ""
                if element.type.hasClosure {
                    if !element.type.isOptional {
                        prefix = String.escaping + " "
                    }
                }
                paramsHaveDefaultVals = false
                return "\(element.name): \(prefix)\(element.type.typeName)"
        }
        .joined(separator: ", ")
        
        paramsAssign = initParamCandidates.map { p in
            return """
                self.\(p.name) = \(p.name.safeName)
            """
        }.joined(separator: "\n")
        
        
        hasBlankInit = needBlankInit || paramsHaveDefaultVals
        initTemplate = """
        \(accessControlLevelDescription)init(\(params)) {
            \(paramsAssign)
            \(String.doneInit) = true
        }
        """
//        initTemplate = """
//        \(accessControlLevelDescription)init(\(params)) {
//            \(paramsAssign)
//        }
//    """
    }
    
    let extraInitParamNames = initParamCandidates.map{$0.name}
    let extraVarsToDecl = declaredInitParamsPerInit.flatMap{$0}.compactMap { (p: ParamModel) -> String? in
        if !extraInitParamNames.contains(p.name) {
            return p.asVarDecl
        }
        return nil
    }
    .joined(separator: "\n")

    var blankInit = ""
    if needBlankInit {
        // In case of protocol mocking, we want to provide a blank init (if not present already) for convenience,
        // where instance vars do not have to be set in init since they all have get/set (see VariableTemplate).
        blankInit = "\(accessControlLevelDescription)init() { \(String.doneInit) = true }"
//        blankInit = "\(accessControlLevelDescription)init() { }"
    }

//    let blankInitFlag = hasBlankInit ? "private let \(String.hasBlankInit) = true" : ""
    let initFlag =  "private var \(String.doneInit) = false"
    let template = """
        \(initFlag)
        \(extraVarsToDecl)
        \(blankInit)
        \(initTemplate)
    """
//    let template = """
//        \(extraVarsToDecl)
//        \(blankInit)
//        \(initTemplate)
//    """

    return template
}

