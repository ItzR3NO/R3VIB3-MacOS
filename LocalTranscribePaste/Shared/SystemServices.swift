import Foundation

protocol FileSystem {
    var temporaryDirectory: URL { get }
    func urls(for directory: FileManager.SearchPathDirectory, in domainMask: FileManager.SearchPathDomainMask) -> [URL]
    func fileExists(atPath path: String) -> Bool
    func isExecutableFile(atPath path: String) -> Bool
    func removeItem(at url: URL) throws
    func createDirectory(at url: URL, withIntermediateDirectories: Bool) throws
    func attributesOfItem(atPath path: String) throws -> [FileAttributeKey: Any]
    func setAttributes(_ attributes: [FileAttributeKey: Any], ofItemAtPath path: String) throws
}

struct SystemFileSystem: FileSystem {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    var temporaryDirectory: URL {
        fileManager.temporaryDirectory
    }

    func urls(for directory: FileManager.SearchPathDirectory, in domainMask: FileManager.SearchPathDomainMask) -> [URL] {
        fileManager.urls(for: directory, in: domainMask)
    }

    func fileExists(atPath path: String) -> Bool {
        fileManager.fileExists(atPath: path)
    }

    func isExecutableFile(atPath path: String) -> Bool {
        fileManager.isExecutableFile(atPath: path)
    }

    func removeItem(at url: URL) throws {
        try fileManager.removeItem(at: url)
    }

    func createDirectory(at url: URL, withIntermediateDirectories: Bool) throws {
        try fileManager.createDirectory(at: url, withIntermediateDirectories: withIntermediateDirectories)
    }

    func attributesOfItem(atPath path: String) throws -> [FileAttributeKey: Any] {
        try fileManager.attributesOfItem(atPath: path)
    }

    func setAttributes(_ attributes: [FileAttributeKey: Any], ofItemAtPath path: String) throws {
        try fileManager.setAttributes(attributes, ofItemAtPath: path)
    }
}

protocol UUIDProviding {
    func makeUUID() -> UUID
}

struct SystemUUIDProvider: UUIDProviding {
    func makeUUID() -> UUID {
        UUID()
    }
}

protocol BundleProviding {
    var bundleIdentifier: String? { get }
    var bundlePath: String { get }
    func url(forResource name: String, withExtension ext: String?, subdirectory: String?) -> URL?
}

struct MainBundleProvider: BundleProviding {
    private let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    var bundleIdentifier: String? { bundle.bundleIdentifier }
    var bundlePath: String { bundle.bundlePath }

    func url(forResource name: String, withExtension ext: String?, subdirectory: String?) -> URL? {
        bundle.url(forResource: name, withExtension: ext, subdirectory: subdirectory)
    }
}

struct ProcessResult {
    let terminationStatus: Int32
    let output: Data
}

protocol ProcessRunning {
    func run(executableURL: URL, arguments: [String]) throws -> ProcessResult
}

struct SystemProcessRunner: ProcessRunning {
    func run(executableURL: URL, arguments: [String]) throws -> ProcessResult {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        return ProcessResult(terminationStatus: process.terminationStatus, output: data)
    }
}

protocol KeyValueStoring {
    func string(forKey key: String) -> String?
    func data(forKey key: String) -> Data?
    func bool(forKey key: String) -> Bool
    func integer(forKey key: String) -> Int
    func object(forKey key: String) -> Any?
    func set(_ value: Any?, forKey key: String)
}

struct UserDefaultsStore: KeyValueStoring {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func string(forKey key: String) -> String? { defaults.string(forKey: key) }
    func data(forKey key: String) -> Data? { defaults.data(forKey: key) }
    func bool(forKey key: String) -> Bool { defaults.bool(forKey: key) }
    func integer(forKey key: String) -> Int { defaults.integer(forKey: key) }
    func object(forKey key: String) -> Any? { defaults.object(forKey: key) }
    func set(_ value: Any?, forKey key: String) { defaults.set(value, forKey: key) }
}

protocol MainThreadRunning {
    func run(_ block: @escaping () -> Void)
    func runAfter(seconds: TimeInterval, _ block: @escaping () -> Void)
}

struct MainThreadRunner: MainThreadRunning {
    func run(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async {
                block()
            }
        }
    }

    func runAfter(seconds: TimeInterval, _ block: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            block()
        }
    }
}

protocol SleepProviding {
    func sleep(microseconds: useconds_t)
}

struct SystemSleeper: SleepProviding {
    func sleep(microseconds: useconds_t) {
        usleep(microseconds)
    }
}
