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

/// Performs uniquifying operations on models of an entity

func generateUniqueModels(protocolMap: [String: Entity],
                          annotatedProtocolMap: [String: Entity],
                          inheritanceMap: [String: Entity],
                          semaphore: DispatchSemaphore?,
                          queue: DispatchQueue?,
                          completion: @escaping (ResolvedEntityContainer) -> ()) {
    if let queue = queue {
        let lock = NSLock()
        for (key, val) in annotatedProtocolMap {
            _ = semaphore?.wait(timeout: DispatchTime.distantFuture)
            queue.async {
                generateUniqueModels(key: key, entity: val, protocolMap: protocolMap, inheritanceMap: inheritanceMap, lock: lock, completion: completion)
                semaphore?.signal()
            }
        }
        queue.sync(flags: .barrier) { }
    } else {
        for (key, val) in annotatedProtocolMap {
            generateUniqueModels(key: key, entity: val, protocolMap: protocolMap, inheritanceMap: inheritanceMap, lock: nil, completion: completion)
        }
    }
}

func generateUniqueModels(key: String,
                          entity: Entity,
                          protocolMap: [String: Entity],
                          inheritanceMap: [String: Entity]) -> ResolvedEntityContainer {
    
    let (models, processedModels, attributes, paths, pathToContentList) = lookupEntities(key: key, declType: entity.entityNode.declType, protocolMap: protocolMap, inheritanceMap: inheritanceMap)
    
    let processedFullNames = processedModels.compactMap {$0.fullName}

    let processedElements = processedModels.compactMap { (element: Model) -> (String, Model)? in
        let name = element.name
        if let rng = name.range(of: String.setCallCountSuffix) {
            return (String(name[name.startIndex..<rng.lowerBound]), element)
        }
        if let rng = name.range(of: String.callCountSuffix) {
            return (String(name[name.startIndex..<rng.lowerBound]), element)
        }
        return nil
    }
    
    var processedLookup = Dictionary<String, Model>()
    processedElements.forEach { (key, val) in processedLookup[key] = val }
    
    let nonMethodModels = models.filter {$0.modelType != .method}
    let methodModels = models.filter {$0.modelType == .method}
    let orderedModels = [nonMethodModels, methodModels].flatMap {$0}
    let x = uniqueEntities(in: orderedModels, exclude: processedLookup, fullnames: processedFullNames)
    let unmockedUniqueEntities = x.filter {!$0.value.processed}
    
    let processedElementsMap = Dictionary(grouping: processedModels) { element in element.fullName }
        .compactMap { (key, value) in value.first }
        .map { element in (element.fullName, element) }
    let mockedUniqueEntities = Dictionary(uniqueKeysWithValues: processedElementsMap)

    let uniqueModels = [mockedUniqueEntities, unmockedUniqueEntities].flatMap {$0}
    
    let whitelist = typealiasWhitelist(in: uniqueModels)
    let resolvedEntity = ResolvedEntity(key: key, entity: entity, uniqueModels: uniqueModels, attributes: attributes, typealiasWhitelist: whitelist)
    
    return ResolvedEntityContainer(entity: resolvedEntity, paths: paths, imports: pathToContentList)
}

func generateUniqueModels(key: String,
                          entity: Entity,
                          protocolMap: [String: Entity],
                          inheritanceMap: [String: Entity],
                          lock: NSLock? = nil,
                          completion: @escaping (ResolvedEntityContainer) -> ()) {
    let ret = generateUniqueModels(key: key, entity: entity, protocolMap: protocolMap, inheritanceMap: inheritanceMap)
    
    lock?.lock()
    completion(ret)
    lock?.unlock()
}


func generateTypeKeys(dependentTypes: [String: Entity],
                      resolvedEntities: [ResolvedEntity],
                      completion: @escaping ([String: String]) -> ()) {
    
    var typeKeys = [String: String]()

    for element in dependentTypes {
        if element.value.entityNode.hasBlankInit {
            let (k, v) = mockTypeKeyVal(element.key)
            typeKeys[k] = v
        }
    }

    let firstFiltered = resolvedEntities.filter { $0.hasBlankInit(with: typeKeys) }
    for element in firstFiltered {
        let (k, v) = mockTypeKeyVal(element.key)
        typeKeys[k] = v
    }
    
    let secondFiltered = firstFiltered.filter { !$0.needValsForInitParams(with: typeKeys) }
    for element in secondFiltered {
        let (k, v) = mockTypeKeyVal(element.key)
        typeKeys[k] = v
    }
    
    completion(typeKeys)
}

func mockTypeKeyVal(_ arg: String)  -> (String, String) {
    var key = arg
    if arg.hasSuffix("Mock"), let k = arg.components(separatedBy: "Mock").first {
        key = k
    }
    
    return (key, key + "Mock()")
}
