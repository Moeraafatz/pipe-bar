import Foundation
import SQLite3

private let SQLITE_TRANSIENT_DESTRUCTOR = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public enum RecipeStoreError: Error, LocalizedError, Sendable {
    case openFailed(String)
    case prepareFailed(String)
    case executionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .openFailed(let m): return "SQLite open failed: \(m)"
        case .prepareFailed(let m): return "SQLite prepare failed: \(m)"
        case .executionFailed(let m): return "SQLite exec failed: \(m)"
        }
    }
}

private final class SQLiteHandle: @unchecked Sendable {
    let pointer: OpaquePointer

    init(path: String) throws {
        var db: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(path, &db, flags, nil) != SQLITE_OK {
            let msg = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "sqlite error"
            if let db { sqlite3_close_v2(db) }
            throw RecipeStoreError.openFailed(msg)
        }
        guard let opened = db else { throw RecipeStoreError.openFailed("nil db") }
        self.pointer = opened
    }

    deinit {
        sqlite3_close_v2(pointer)
    }
}

public actor RecipeStore {
    public let databaseURL: URL
    private let handle: SQLiteHandle
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public static func defaultDatabaseURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("PipeBar", isDirectory: true).appendingPathComponent("recipes.sqlite")
    }

    public init(databaseURL: URL = RecipeStore.defaultDatabaseURL()) throws {
        self.databaseURL = databaseURL
        try FileManager.default.createDirectory(at: databaseURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        self.handle = try SQLiteHandle(path: databaseURL.path)
        try Self.bootstrap(db: handle.pointer)
    }

    private static func bootstrap(db: OpaquePointer) throws {
        let sql = """
        PRAGMA journal_mode = WAL;
        PRAGMA synchronous = NORMAL;

        CREATE TABLE IF NOT EXISTS recipes (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            run_count INTEGER NOT NULL DEFAULT 0,
            updated_at REAL NOT NULL,
            payload_json BLOB NOT NULL
        );

        CREATE INDEX IF NOT EXISTS idx_recipes_runs ON recipes(run_count DESC, updated_at DESC);
        """
        var errMsg: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &errMsg) != SQLITE_OK {
            let msg = errMsg.map { String(cString: $0) } ?? "schema init failed"
            sqlite3_free(errMsg)
            throw RecipeStoreError.executionFailed(msg)
        }
    }

    public func upsert(_ recipe: SavedRecipe) throws {
        let sql = """
        INSERT INTO recipes (id, title, run_count, updated_at, payload_json)
        VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
            title = excluded.title,
            run_count = excluded.run_count,
            updated_at = excluded.updated_at,
            payload_json = excluded.payload_json;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle.pointer, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw RecipeStoreError.prepareFailed(lastError())
        }
        defer { sqlite3_finalize(stmt) }

        let payload = try encoder.encode(recipe)
        sqlite3_bind_text(stmt, 1, recipe.id.uuidString, -1, SQLITE_TRANSIENT_DESTRUCTOR)
        sqlite3_bind_text(stmt, 2, recipe.title, -1, SQLITE_TRANSIENT_DESTRUCTOR)
        sqlite3_bind_int64(stmt, 3, Int64(recipe.runCount))
        sqlite3_bind_double(stmt, 4, Date().timeIntervalSince1970)
        _ = payload.withUnsafeBytes { raw in
            sqlite3_bind_blob(stmt, 5, raw.baseAddress, Int32(payload.count), SQLITE_TRANSIENT_DESTRUCTOR)
        }

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw RecipeStoreError.executionFailed(lastError())
        }
    }

    public func fetchAll() throws -> [SavedRecipe] {
        let sql = "SELECT payload_json FROM recipes ORDER BY run_count DESC, updated_at DESC;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle.pointer, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw RecipeStoreError.prepareFailed(lastError())
        }
        defer { sqlite3_finalize(stmt) }

        var list: [SavedRecipe] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let bytes = sqlite3_column_blob(stmt, 0) {
                let len = Int(sqlite3_column_bytes(stmt, 0))
                if let r = try? decoder.decode(SavedRecipe.self, from: Data(bytes: bytes, count: len)) {
                    list.append(r)
                }
            }
        }
        return list
    }

    public func wipeAll() throws {
        var errMsg: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(handle.pointer, "DELETE FROM recipes; VACUUM;", nil, nil, &errMsg) != SQLITE_OK {
            let msg = errMsg.map { String(cString: $0) } ?? "wipe failed"
            sqlite3_free(errMsg)
            throw RecipeStoreError.executionFailed(msg)
        }
    }

    public func databaseFileSizeBytes() -> Int64 {
        let paths = [databaseURL.path, databaseURL.path + "-wal", databaseURL.path + "-shm"]
        var total: Int64 = 0
        for p in paths {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: p),
               let sz = attrs[.size] as? NSNumber {
                total += sz.int64Value
            }
        }
        return total
    }

    private func lastError() -> String {
        String(cString: sqlite3_errmsg(handle.pointer))
    }
}
