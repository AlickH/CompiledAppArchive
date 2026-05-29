#!/usr/bin/env swift

import Darwin
import Foundation

let trash = "\(NSHomeDirectory())/.Trash/Office/"

let wordPath = "/Applications/Microsoft Word.app"
let excelPath = "/Applications/Microsoft Excel.app"
let oneNotePath = "/Applications/Microsoft OneNote.app"
let outlookPath = "/Applications/Microsoft Outlook.app"
let powerPointPath = "/Applications/Microsoft PowerPoint.app"

let paths = [
    wordPath,
    excelPath,
    oneNotePath,
    outlookPath,
    powerPointPath,
]

enum OfficeThinnerError: Error, CustomStringConvertible {
    case posix(String, Int32)
    case noOfficeApp([String])
    case cannotReadDirectory(String)

    var description: String {
        switch self {
        case let .posix(operation, code):
            return "\(operation): \(String(cString: strerror(code)))"
        case let .noOfficeApp(paths):
            return "Don't exist path in \(paths)"
        case let .cannotReadDirectory(path):
            return "Cannot read directory \(path)"
        }
    }
}

func statInfo(_ path: String) throws -> stat {
    var info = stat()
    if lstat(path, &info) != 0 {
        throw OfficeThinnerError.posix("lstat \(path)", errno)
    }
    return info
}

func regularFileInfoIfExists(_ path: String) throws -> stat? {
    var info = stat()
    if lstat(path, &info) != 0 {
        if errno == ENOENT {
            return nil
        }
        throw OfficeThinnerError.posix("lstat \(path)", errno)
    }

    if (info.st_mode & S_IFMT) != S_IFREG {
        return nil
    }

    return info
}

func sameContent(_ path1: String, _ path2: String, size: off_t) throws -> Bool {
    let handle1 = try FileHandle(forReadingFrom: URL(fileURLWithPath: path1))
    let handle2 = try FileHandle(forReadingFrom: URL(fileURLWithPath: path2))
    defer {
        try? handle1.close()
        try? handle2.close()
    }

    if size == 0 {
        return true
    }

    let chunkSize = 1024 * 1024
    while true {
        let data1 = try handle1.read(upToCount: chunkSize) ?? Data()
        let data2 = try handle2.read(upToCount: chunkSize) ?? Data()

        if data1 != data2 {
            return false
        }

        if data1.isEmpty {
            return true
        }
    }
}

func backupFile(_ filename: String) throws {
    let destFilename = trash + filename
    let destDirectory = (destFilename as NSString).deletingLastPathComponent

    try FileManager.default.createDirectory(
        atPath: destDirectory,
        withIntermediateDirectories: true
    )

    print("Move \(filename) to \(destFilename)")
    try FileManager.default.moveItem(atPath: filename, toPath: destFilename)
}

func hardLink(from targetFile: String, to filename: String) throws {
    if link(targetFile, filename) != 0 {
        throw OfficeThinnerError.posix("link \(targetFile) \(filename)", errno)
    }
}

func findAndTrimSameFiles(targetDir: String, dir: String) throws {
    guard let enumerator = FileManager.default.enumerator(atPath: dir) else {
        throw OfficeThinnerError.cannotReadDirectory(dir)
    }

    for case let relativePath as String in enumerator {
        let relPath = "/" + relativePath
        let filename = dir + relPath
        let targetFile = targetDir + relPath

        let sourceInfo = try statInfo(filename)
        if (sourceInfo.st_mode & S_IFMT) != S_IFREG {
            continue
        }

        guard let targetInfo = try regularFileInfoIfExists(targetFile) else {
            continue
        }

        if sourceInfo.st_ino == targetInfo.st_ino {
            continue
        }

        if sourceInfo.st_size != targetInfo.st_size {
            continue
        }

        if try !sameContent(targetFile, filename, size: sourceInfo.st_size) {
            continue
        }

        try backupFile(filename)
        try hardLink(from: targetFile, to: filename)
    }
}

func main() throws {
    if geteuid() != 0 {
        print("Need root privilege, Please run: sudo \(CommandLine.arguments[0])")
        exit(1)
    }

    var targetPath: String?
    var trimPaths: [String] = []

    for path in paths where FileManager.default.fileExists(atPath: path) {
        if targetPath == nil {
            targetPath = path
        } else {
            trimPaths.append(path)
        }
    }

    guard let targetPath else {
        throw OfficeThinnerError.noOfficeApp(paths)
    }

    print("Trim \(trimPaths) with \(targetPath)")
    for path in trimPaths {
        print("\(targetPath), \(path)")
        try findAndTrimSameFiles(targetDir: targetPath, dir: path)
    }

    print("Office thinning completed!")
    print("Backup files in \(trash), you view or delete the files later by Finder Trash.")
}

do {
    try main()
} catch {
    print(error)
    exit(1)
}
