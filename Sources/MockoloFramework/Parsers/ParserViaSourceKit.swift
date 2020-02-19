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

public class ParserViaSourceKit: SourceParsing {
    
    public init() {}
    
    public func parseProcessedDecls(_ paths: [String],
                                    semaphore: DispatchSemaphore?,
                                    queue: DispatchQueue?,
                                    completion: @escaping ([Entity], [String: [String]]?) -> ()) {
        
        if let queue = queue {
            let lock = NSLock()
            for filePath in paths {
                _ = semaphore?.wait(timeout: DispatchTime.distantFuture)
                queue.async {
                    self.generateProcessedASTs(filePath, lock: lock, completion: completion)
                    semaphore?.signal()
                }
            }
            // Wait for queue to drain
            queue.sync(flags: .barrier) {}
        } else {
            for filePath in paths {
                generateProcessedASTs(filePath, lock: nil, completion: completion)
            }
        }
    }
    
    public func parseDecls(_ paths: [String]?,
                           isDirs: Bool,
                           exclusionSuffixes: [String]? = nil,
                           annotation: String,
                           semaphore: DispatchSemaphore?,
                           queue: DispatchQueue?,
                           completion: @escaping ([Entity], [String: [String]]?) -> ()) {
        guard !annotation.isEmpty else { return }
        guard let paths = paths else { return }
        if isDirs {
            generateASTs(dirs: paths, exclusionSuffixes: exclusionSuffixes, annotation: annotation, semaphore: semaphore, queue: queue, completion: completion)
        } else {
            generateASTs(files: paths, exclusionSuffixes: exclusionSuffixes, annotation: annotation, semaphore: semaphore, queue: queue, completion: completion)
        }
    }
    
    private func generateASTs(dirs: [String],
                                  exclusionSuffixes: [String]? = nil,
                                  annotation: String,
                                  semaphore: DispatchSemaphore?,
                                  queue: DispatchQueue?,
                                  completion: @escaping ([Entity], [String: [String]]?) -> ()) {
        
        guard let annotationData = annotation.data(using: .utf8) else {
            fatalError("Annotation is invalid: \(annotation)")
        }
        if let queue = queue {
            let lock = NSLock()
            
            scanPaths(dirs) { filePath in
                _ = semaphore?.wait(timeout: DispatchTime.distantFuture)
                queue.async {
                    self.generateASTs(filePath,
                                          exclusionSuffixes: exclusionSuffixes,
                                          annotationData: annotationData,
                                          lock: lock,
                                          completion: completion)
                    semaphore?.signal()
                }
            }
            
            // Wait for queue to drain
            queue.sync(flags: .barrier) {}
        } else {
            scanPaths(dirs) { filePath in
                generateASTs(filePath,
                                 exclusionSuffixes: exclusionSuffixes,
                                 annotationData: annotationData,
                                 lock: nil,
                                 completion: completion)
            }
        }
    }
    
    private func generateASTs(files: [String],
                                  exclusionSuffixes: [String]? = nil,
                                  annotation: String,
                                  semaphore: DispatchSemaphore?,
                                  queue: DispatchQueue?,
                                  completion: @escaping ([Entity], [String: [String]]?) -> ()) {
        guard let annotationData = annotation.data(using: .utf8) else {
            fatalError("Annotation is invalid: \(annotation)")
        }
        
        if let queue = queue {
            let lock = NSLock()
            for filePath in files {
                _ = semaphore?.wait(timeout: DispatchTime.distantFuture)
                queue.async {
                    self.generateASTs(filePath,
                                          exclusionSuffixes: exclusionSuffixes,
                                          annotationData: annotationData,
                                          lock: lock,
                                          completion: completion)
                    semaphore?.signal()
                }
            }
            // Wait for queue to drain
            queue.sync(flags: .barrier) {}
            
        } else {
            for filePath in files {
                generateASTs(filePath,
                                 exclusionSuffixes: exclusionSuffixes,
                                 annotationData: annotationData,
                                 lock: nil,
                                 completion: completion)
            }
        }
    }
    
    private func generateASTs(_ path: String,
                                  exclusionSuffixes: [String]? = nil,
                                  annotationData: Data,
                                  lock: NSLock?,
                                  completion: @escaping ([Entity], [String: [String]]?) -> ()) {
        
        guard path.shouldParse(with: exclusionSuffixes) else { return }
        guard let content = FileManager.default.contents(atPath: path) else {
            fatalError("Retrieving contents of \(path) failed")
        }
        
        do {
            var results = [Entity]()
            let topstructure = try Structure(path: path)
            for current in topstructure.substructures {
                guard current.isProtocol else {continue}
                let metadata = current.annotationMetadata(with: annotationData, in: content)
                if let node = Entity.node(with: current, filepath: path, data: content, isPrivate: current.isPrivate, isFinal: current.isFinal, metadata: metadata, processed: false) {
                    results.append(node)
                }
            }
            
            lock?.lock()
            completion(results, nil)
            lock?.unlock()
            
        } catch {
            fatalError(error.localizedDescription)
        }
    }
    
    private func generateProcessedASTs(_ path: String,
                                           lock: NSLock?,
                                           completion: @escaping ([Entity], [String: [String]]) -> ()) {
        
        guard let content = FileManager.default.contents(atPath: path) else {
            fatalError("Retrieving contents of \(path) failed")
        }
        
        do {
            let topstructure = try Structure(path: path)
            let subs = topstructure.substructures
            let results = subs.compactMap { current -> Entity? in
                return Entity.node(with: current, filepath: path, data: content, isPrivate: current.isPrivate, isFinal: current.isFinal, metadata: nil, processed: true)
            }
            
            let imports = findImportLines(data: content, offset: subs.first?.offset)
            lock?.lock()
            completion(results, [path: imports])
            lock?.unlock()
        } catch {
            fatalError(error.localizedDescription)
        }
    }
}


