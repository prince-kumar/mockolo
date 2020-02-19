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

public typealias Loc = (name: String, docLoc: (Int, Int))
public struct Entry {
    var path: String
    var module: String
    var parents: [String]
    var docLoc: (Int, Int)
}

public func cleanup(sourceDirs: [String]?,
                    exclusionSuffixes: [String]? = nil,
                    annotation: String,
                    outputFilePath: String? = nil,
                    concurrencyLimit: Int? = nil) {
    
    let dirs = sourceDirs ?? []
    let p = ParserViaSwiftSyntax()
    
    log("Scan used types...")
    let t0 = CFAbsoluteTimeGetCurrent()
    let (protocolMap, annotatedProtocolMap, usedProtocolMap) = scanUsedTypes(dirs: dirs, exclusionSuffixes: exclusionSuffixes, annotation: annotation, parser: p)
    
    log("Check for unused types...")
    let t2 = CFAbsoluteTimeGetCurrent()
    let (unusedProtocolMap, usedList) = checkUnusedTypes(annotatedProtocolMap, protocolMap, usedProtocolMap)
    let t3 = CFAbsoluteTimeGetCurrent()
    log("---", t3-t2)
    log("- Used list", usedList.count)
    
    log("Save unused types...")
    let unusedCount = saveUnusedTypes(unusedProtocolMap, outputFilePath)
    let t4 = CFAbsoluteTimeGetCurrent()
    log("---", t4-t3)
    
    log("Remove unnecessary annotations from files...")
    removeAnnotations(dirs, exclusionSuffixes, annotation, unusedProtocolMap, concurrencyLimit)
    let t5 = CFAbsoluteTimeGetCurrent()
    log("---", t5-t4)
    
    log("#Protocols", protocolMap.count, "#Annotated", annotatedProtocolMap.count, "Used", usedProtocolMap.count, "Unused", unusedCount)
    log("Total (s)", t5-t0)
}


public func scanUsedTypes(dirs: [String],
                          exclusionSuffixes: [String]?,
                          annotation: String,
                          parser: ParserViaSwiftSyntax) -> ([String: Entry], [String: Entry], [String: [String]]){
    
    var annotatedProtocolMap = [String: Entry]()
    var protocolMap = [String: Entry]()
    var usedProtocolMap = [String: [String]]()

    log("First pass: scan all / annotated types...")
    let t0 = CFAbsoluteTimeGetCurrent()
    scanPaths(dirs) { filePath in
        //    for filePath in dirs {
        if !filePath.contains("___"), filePath.shouldParse(with: exclusionSuffixes) {
            parser.scanMockableTypes(filePath, annotation, completion: { (argUsedTypes: [String], argProtocolMap: [String : (annotated: Bool, parents: [String], docLoc: (Int, Int))]) in
                
                let module = filePath.module
                
                let usedSet = Set(argUsedTypes)
                for usedType in usedSet {
                    if usedProtocolMap[usedType] == nil {
                        usedProtocolMap[usedType] = []
                    }
                    
                    if let list = usedProtocolMap[usedType], !list.contains(module) {
                        usedProtocolMap[usedType]?.append(module)
                    }
                }
                
                for (k, v) in argProtocolMap {
                    let parentlist = v.parents.filter{$0 != "AnyObject" && $0 != "class" && $0 != "Any"}
                    let ent = Entry(path: filePath, module: module, parents: parentlist, docLoc: v.docLoc)
                    protocolMap[k] = ent
                    if v.annotated {
                        annotatedProtocolMap[k] = ent
                    }
                }
            })
        }
    }
    let t1 = CFAbsoluteTimeGetCurrent()
    log("---", t1-t0)

    log("Second pass: scan used types...")
    scanPaths(dirs) { filePath in
        if !filePath.contains("___"),
            filePath.hasSuffix(".swift"),
            (filePath.contains("Tests") || filePath.contains("Mocks.swift")) {
            parser.scanUsedTypes(filePath, "", completion: { (argUsedTypes: [String]) in
                let pathstr = filePath.components(separatedBy: "Tests").first ?? ""
                let module = pathstr.module
                let usedSet = Set(argUsedTypes)
                for usedType in usedSet {
                    if usedProtocolMap[usedType] == nil {
                        usedProtocolMap[usedType] = []
                    }
                    
                    if let list = usedProtocolMap[usedType], !list.contains(module) {
                        usedProtocolMap[usedType]?.append(module)
                    }
                }
            })
        }
    }
    let t2 = CFAbsoluteTimeGetCurrent()
    log("---", t2-t1)

    return (protocolMap, annotatedProtocolMap, usedProtocolMap)
}

public func scanUsedTypse(files: [String],
                          parser: ParserViaSwiftSyntax) -> [String: [String]] {
    
    var usedProtocolMap = [String: [String]]()
    for filePath in files {
        if //!filePath.contains("___"),
            filePath.hasSuffix(".swift"),
            (true || filePath.contains("Tests") || filePath.contains("Mocks.swift"))
        {
            parser.scanUsedTypes(filePath, "", completion: { (argUsedTypes: [String]) in
                let pathstr = filePath.components(separatedBy: "Tests").first ?? ""
                let module = pathstr.module
                
                let usedSet = Set(argUsedTypes)
                
                for usedType in usedSet {
                    if usedProtocolMap[usedType] == nil {
                        usedProtocolMap[usedType] = []
                    }
                    
                    if let list = usedProtocolMap[usedType], !list.contains(module) {
                        usedProtocolMap[usedType]?.append(module)
                    }
                }
            })
        }
    }
    return usedProtocolMap
}

public func checkUnusedTypes(_ annotatedProtocolMap: [String: Entry],
                             _ protocolMap: [String: Entry],
                             _ usedTypeMap: [String: [String]]) -> ([String: [Loc]], [String: [String]]) {
    
    // For each parent, check if it's in used_map.
    // If not, check the path of the parent from protocolMap.
    // If the path is same as annotated protocol's, add to unusedMap.
    var unusedProtocolMap = [String: [Loc]]()
    var usedList = [String: [String]]()
    let level = 0
    
    for (curType, curVal) in annotatedProtocolMap {
        findUnusedTypes(curType, curVal.module, protocolMap, usedTypeMap, &unusedProtocolMap, &usedList, level)
    }
    
    // filter used list from unused
    let reallyUnusedMap = unusedProtocolMap.filter { (path: String, value: [Loc]) -> Bool in
        for v in value {
            if usedList[path]?.contains(v.name) ?? false {
                return false
            }
            
            if let _ = usedTypeMap[v.name] {
                return false
            }
        }
        return !value.isEmpty
    }
    
    return (reallyUnusedMap, usedList)
}

private func findUnusedTypes(_ curType: String,
                             _ curModule: String,
                             _ protocolMap: [String: Entry],
                             _ usedTypeMap:  [String: [String]],
                             _ unusedProtocolMap: inout [String: [Loc]],
                             _ usedList: inout [String: [String]],
                             _ level: Int) {
    if let _ = usedTypeMap[curType] {
    } else if let val = protocolMap[curType] {
        let unusedPath = val.path
        if curModule == val.module {
            var add = true
            if unusedProtocolMap[unusedPath] == nil {
                unusedProtocolMap[unusedPath] = []
            } else {
                if let locs = unusedProtocolMap[unusedPath] {
                    let dupes = locs.filter {$0.name == curType && $0.docLoc == val.docLoc }
                    if !dupes.isEmpty {
                        add = false
                    }
                }
            }
            if add {
                unusedProtocolMap[unusedPath]?.append(Loc(name: curType, docLoc: val.docLoc))
            }
        } else {
            if usedList[unusedPath] == nil {
                usedList[unusedPath] = []
            }
            usedList[unusedPath]?.append(curType)
        }
        
        for parent in val.parents {
            findUnusedTypes(parent, curModule, protocolMap, usedTypeMap, &unusedProtocolMap, &usedList, level+1)
        }
    }
}

public func saveUnusedTypes(_ unusedProtocolMap: [String: [Loc]],
                            _ outputFilePath: String?) -> Int {
    // save unused protocols and their filepaths
    let unusedListStr = unusedProtocolMap.map { (path: String, value: [Loc]) -> String in
        return value.compactMap{"\($0.name): \(path)"}.joined(separator: "\n")
    }.joined(separator: "\n")
    
    let unusedCount = unusedProtocolMap.values.flatMap{$0}.count
    log("Found", unusedCount, " unused protocols")
    if let outputFilePath = outputFilePath {
        try? unusedListStr.write(toFile: outputFilePath, atomically: true, encoding: .utf8)
        log("Saving to", outputFilePath)
    }
    return unusedCount
}

public func removeAnnotations(_ dirs: [String],
                              _ exclusionSuffixes: [String]?,
                              _ annotation: String,
                              _ unusedProtocolMap: [String: [Loc]],
                              _ concurrencyLimit: Int?) {
    
    let maxConcurrentThreads = concurrencyLimit ?? 1
    let sema = maxConcurrentThreads <= 1 ? nil: DispatchSemaphore(value: maxConcurrentThreads)
    let queue = maxConcurrentThreads == 1 ? nil: DispatchQueue(label: "cleanup-q", qos: DispatchQoS.userInteractive, attributes: DispatchQueue.Attributes.concurrent)
    
    if let queue = queue {
        let lock = NSLock()
        scanPaths(dirs) { filePath in
            _ = sema?.wait(timeout: DispatchTime.distantFuture)
            queue.async {
                replace(filePath, unusedProtocolMap[filePath], exclusionSuffixes, annotation, lock) { data in
                    let url = URL(fileURLWithPath: filePath)
                    do {
                        try data.write(to: url, options: Data.WritingOptions.atomicWrite)
                    } catch {
                        fatalError(error.localizedDescription)
                    }
                }
                sema?.signal()
            }
        }
        queue.sync(flags: .barrier) {}
    } else {
        scanPaths(dirs) { filePath in
            replace(filePath, unusedProtocolMap[filePath], exclusionSuffixes, annotation, nil) { data in
                let url = URL(fileURLWithPath: filePath)
                do {
                    try data.write(to: url, options: Data.WritingOptions.atomicWrite)
                } catch {
                    fatalError(error.localizedDescription)
                }
            }
        }
    }
}

public func replace(_ path: String,
                     _ locs: [Loc]?,
                     _ exclusionSuffixes: [String]?,
                     _ annotation: String,
                     _ lock: NSLock?,
                     _ completion: @escaping (Data) -> ()) {
    let original = "/// \(annotation)"
    let newline = "\n"
    let space = String(repeating: " ", count: original.count)
    
    guard !path.contains("___"), path.shouldParse(with: exclusionSuffixes) else { return }
    
    guard let originalData = original.data(using: .utf8),
        let newlineData = newline.data(using: .utf8),
        let spaceData = space.data(using: .utf8),
        let locs = locs else {return}
    
    guard var content = FileManager.default.contents(atPath: path) else {
        fatalError("Retrieving contents of \(path) failed")
    }
    
    var ranges = [Range<Data.Index>]()
    for loc in locs {
        let start = loc.docLoc.0
        let end = loc.docLoc.1
        
        if let annotationRange = content.range(of: originalData, options: [], in: start..<end) {
            let anStart = annotationRange.startIndex
            let anEnd = annotationRange.endIndex
            if let newlingRange = content.range(of: newlineData, options: [], in: anEnd..<end) {
                let lineStart = newlingRange.startIndex
                
                if lineStart == anEnd {
                    ranges.append(annotationRange)
                } else {
                    ranges.append(anStart..<lineStart)
                }
            }
        }
    }
    
    for r in ranges {
        let len = r.endIndex-r.startIndex
        if len == originalData.count {
            content.replaceSubrange(r, with: spaceData)
        } else {
            if let extraSpaces = String(repeating: " ", count: len).data(using: .utf8) {
                content.replaceSubrange(r, with: extraSpaces)
            }
        }
    }
    
    lock?.lock()
    completion(content)
    lock?.unlock()
}

