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
import SPMUtility
import MockoloFramework

class Executor {
    let defaultTimeout = 20
    
    // MARK: - Private
    private var loggingLevel: OptionArgument<Int>!
    private var outputFilePath: OptionArgument<String>!
    private var mockFilePaths: OptionArgument<[String]>!
    private var sourceDirs: OptionArgument<[String]>!
    private var sourceFiles: OptionArgument<[String]>!
    private var sourceFileList: OptionArgument<String>!
    private var depFileList: OptionArgument<String>!
    private var exclusionSuffixes: OptionArgument<[String]>!
    private var header: OptionArgument<String>!
    private var macro: OptionArgument<String>!
    private var annotation: OptionArgument<String>!
    private var concurrencyLimit: OptionArgument<Int>!
    private var useSourceKit: OptionArgument<Bool>!
    
    /// Initializer.
    ///
    /// - parameter name: The name used to check if this command should
    /// be executed.
    /// - parameter overview: The overview description of this command.
    /// - parameter parser: The argument parser to use.
    init(parser: ArgumentParser) {
        setupArguments(with: parser)
    }
    
    /// Setup the arguments using the given parser.
    ///
    /// - parameter parser: The argument parser to use.
    private func setupArguments(with parser: ArgumentParser) {
        loggingLevel = parser.add(option: "--logging-level",
                                  shortName: "-v",
                                  kind: Int.self,
                                  usage: "The logging level to use. Default is set to 0 (info only). Set 1 for verbose, 2 for warning, and 3 for error.")
        sourceFiles = parser.add(option: "--sourcefiles",
                                 shortName: "-srcs",
                                 kind: [String].self,
                                 usage: "List of source files (separated by a comma or a space) to generate mocks for. If the --sourcedirs or --filelist value exists, this will be ignored. ",
                                 completion: .filename)
        sourceFileList = parser.add(option: "--filelist",
                                 shortName: "-f",
                                 kind: String.self,
                                 usage: "Path to a file containing a list of source file paths (delimited by a new line). If the --sourcedirs value exists, this will be ignored. ",
                                 completion: .filename)
        sourceDirs = parser.add(option: "--sourcedirs",
                                shortName: "-s",
                                kind: [String].self,
                                usage: "Paths to the directories containing source files to generate mocks for. If the --filelist or --sourcefiles values exist, they will be ignored. ",
                                completion: .filename)
        depFileList = parser.add(option: "--depfilelist",
                                   shortName: "-deplist",
                                   kind: String.self,
                                   usage: "Path to a file containing a list of dependent files (separated by a new line) from modules this target depends on. ",
                                   completion: .filename)
        mockFilePaths = parser.add(option: "--mockfiles",
                                   shortName: "-mocks",
                                   kind: [String].self,
                                   usage: "List of mock files (separated by a comma or a space) from modules this target depends on. If the --depfilelist value exists, this will be ignored.",
                                   completion: .filename)
        outputFilePath = parser.add(option: "--destination",
                                    shortName: "-d",
                                    kind: String.self,
                                    usage: "Output file path containing the generated Swift mock classes. If no value is given, the program will exit.",
                                    completion: .filename)
        exclusionSuffixes = parser.add(option: "--exclude-suffixes",
                                       shortName: "-x",
                                       kind: [String].self,
                                       usage: "List of filename suffix(es) without the file extensions to exclude from parsing (separated by a comma or a space).",
                                       completion: .filename)
        annotation = parser.add(option: "--annotation",
                                shortName: "-a",
                                kind: String.self,
                                usage: "A custom annotation string used to indicate if a type should be mocked (default = @mockable).")
        macro = parser.add(option: "--macro",
                                shortName: "-m",
                                kind: String.self,
                                usage: "If set, #if [macro] / #endif will be added to the generated mock file content to guard compilation.")
        header = parser.add(option: "--header",
                                shortName: "-h",
                                kind: String.self,
                                usage: "A custom header documentation to be added to the beginning of a generated mock file.")
        concurrencyLimit = parser.add(option: "--concurrency-limit",
                                      shortName: "-j",
                                      kind: Int.self,
                                      usage: "Maximum number of threads to execute concurrently (default = number of cores on the running machine).")
        useSourceKit = parser.add(option: "--use-sourcekit",
                             kind: Bool.self,
                             usage: "Whether to use SourceKit for parsing. By default it will use SwiftSyntax.")
    }
    
    private func fullPath(_ path: String) -> String {
        if path.hasPrefix("/") {
            return path
        }
        if path.hasPrefix("~") {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            return path.replacingOccurrences(of: "~", with: home, range: path.range(of: "~"))
        }
        return FileManager.default.currentDirectoryPath + "/" + path
    }
    
    /// Execute the command.
    ///
    /// - parameter arguments: The command line arguments to execute the command with.
    func execute(with arguments: ArgumentParser.Result) {
        let root = "/Users/ellie/uber/ios"
//        let dirs = [root + "/libraries/foundation"]
        let dirs = [root + "/libraries",
                    root + "/apps/iphone-helix", root + "/apps/carbon", root + "/apps/jump", root + "/apps/iphone-eats", root + "/apps/jump-ops"]
        let xlist = "Tests Test Images Strings Models Services Fixture Screen Scene UITest Names"
        let ofile = root + "/unused"
        do {
            try generate(sourceDirs: dirs,
                         sourceFiles: nil,
                         parser: ParserViaSourceKit(),
                         exclusionSuffixes: xlist.components(separatedBy: " "),
                         mockFilePaths: nil,
                         annotation: "@CreateMock",
                         header: nil,
                         macro: nil,
                         to: ofile,
                         loggingLevel: 1,
                         concurrencyLimit: 1, //nil,
                         onCompletion: { _ in
                    log("Done. Exiting program.", level: .info)
                    exit(0)
            })
        } catch {
            fatalError("Generation error: \(error)")
        }
        
/// @CreateMock

        guard let outputArg = arguments.get(outputFilePath) else { fatalError("Missing destination file path") }
        let outputFilePath = fullPath(outputArg)

        let srcDirs = arguments.get(sourceDirs)?.map(fullPath)
        var srcs: [String]?
        // If source file list exists, source files value will be overriden (see the usage in setupArguments above)
        if let srcList = arguments.get(sourceFileList) {
            let text = try? String(contentsOfFile: srcList, encoding: String.Encoding.utf8)
            srcs = text?.components(separatedBy: "\n").filter{!$0.isEmpty}.map(fullPath)
        } else {
            srcs = arguments.get(sourceFiles)?.map(fullPath)
        }

        if srcDirs == nil, srcs == nil {
            fatalError("Missing source files or directories")
        }
        
        var mockFilePaths: [String]?
        // If dep file list exists, mock filepaths value will be overriden (see the usage in setupArguments above)
        if let depList = arguments.get(self.depFileList) {
            let text = try? String(contentsOfFile: depList, encoding: String.Encoding.utf8)
            mockFilePaths = text?.components(separatedBy: "\n").filter{!$0.isEmpty}.map(fullPath)
        } else {
             mockFilePaths = arguments.get(self.mockFilePaths)?.map(fullPath)
        }

        let concurrencyLimit = arguments.get(self.concurrencyLimit)
        let exclusionSuffixes = arguments.get(self.exclusionSuffixes) ?? []
        let annotation = arguments.get(self.annotation) ?? String.mockAnnotation
        let header = arguments.get(self.header)
        let loggingLevel = arguments.get(self.loggingLevel) ?? 0
        let macro = arguments.get(self.macro)
        let shouldUseSourceKit = arguments.get(useSourceKit) ?? false

        do {
            try generate(sourceDirs: srcDirs,
                         sourceFiles: srcs,
                         parser: shouldUseSourceKit ? ParserViaSourceKit() : ParserViaSwiftSyntax(),
                         exclusionSuffixes: exclusionSuffixes,
                         mockFilePaths: mockFilePaths,
                         annotation: annotation,
                         header: header,
                         macro: macro,
                         to: outputFilePath,
                         loggingLevel: loggingLevel,
                         concurrencyLimit: concurrencyLimit,
                         onCompletion: { _ in
                    log("Done. Exiting program.", level: .info)
                    exit(0)
            })
        } catch {
            fatalError("Generation error: \(error)")
        }
    }
}
