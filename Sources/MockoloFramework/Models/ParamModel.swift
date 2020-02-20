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
import SourceKittenFramework

final class ParamModel: Model {
    var name: String
    var offset: Int64
    var length: Int64
    var type: Type
    let label: String
    let isGeneric: Bool
    let inInit: Bool
    let needVarDecl: Bool
    
    var modelType: ModelType {
        return .parameter
    }

    var fullName: String {
        return label + "_" + name
    }

    init(label: String = "", name: String, typeName: String, isGeneric: Bool = false, inInit: Bool = false, needVarDecl: Bool, offset: Int64, length: Int64) {
        self.name = name.trimmingCharacters(in: .whitespaces)
        self.type = Type(typeName.trimmingCharacters(in: .whitespaces))
        let labelStr = label.trimmingCharacters(in: .whitespaces)
        self.label = name != labelStr ? labelStr : ""
        self.offset = offset
        self.length = length
        self.isGeneric = isGeneric
        self.inInit = inInit
        self.needVarDecl = needVarDecl
    }
    
    init(_ ast: Structure, label: String = "", offset: Int64, length: Int64, data: Data, isGeneric: Bool = false, inInit: Bool = false, needVarDecl: Bool) {
        self.name = ast.name
        self.offset = offset
        self.length = length
        // Sourcekit doesn't specify if a func arg is variadic, so look ahead for the following characters to  determine.
        let lookahead = data.toString(offset: offset + length, length: 3)
        let isVariadic = lookahead == "..."
        self.isGeneric = isGeneric
        self.inInit = inInit
        self.needVarDecl = needVarDecl
        let typeArg = isGeneric ? (ast.inheritedTypes.first ?? .unknownVal) : (isVariadic ? ast.typeName + "..." : ast.typeName)
        self.type = Type(typeArg)
        self.label = ast.name != label ? label : ""
    }

    var asVarDecl: String? {
        if self.inInit, self.needVarDecl {
            return applyVarTemplate(name: name, type: type)
        }
        return nil
    }
    
    func render(with identifier: String, typeKeys: [String: String]? = nil) -> String? {
        return applyParamTemplate(name: name, label: label, type: type, inInit: inInit)
    }
}
