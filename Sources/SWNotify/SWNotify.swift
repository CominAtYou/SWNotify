import Foundation
import CNotify

public enum NotifierError: Error {
    case failedToAddNotifier
    case failedToRemoveNotifier
}

public enum FileSystemEvent: Int32 {
    case create = 0x0100
    case delete = 0x0200
    case modify = 0x0002
    case rename = 0x00C0
}

public class Notifier {
    private static let _default = Notifier()
    private var watches: [String: Int32] = [:]

    private var createCallbacks: [UUID : (String) -> Void] = [:]
    private var deleteCallbacks: [UUID : (String) -> Void] = [:]
    private var modifyCallbacks: [UUID : (String) -> Void] = [:]
    private var moveCallbacks: [UUID : (String, String) -> Void] = [:]

    private let onFileCreated: @convention(c) (UnsafePointer<CChar>?) -> Void = { filepath in
        guard let filepath else {
            return
        }

        _default.createCallbacks.values.forEach { $0(String(cString: filepath)) }
    }

    private let onFileDeleted: @convention(c) (UnsafePointer<CChar>?) -> Void = { filepath in
        guard let filepath else {
            return
        }

        _default.deleteCallbacks.values.forEach { $0(String(cString: filepath)) }
    }

    private let onFileModified: @convention(c) (UnsafePointer<CChar>?) -> Void = { filepath in
        guard let filepath else {
            return
        }

        _default.modifyCallbacks.values.forEach { $0(String(cString: filepath)) }
    }

    private let onFileMoved: @convention(c) (UnsafePointer<CChar>?, UnsafePointer<CChar>?) -> Void = { oldFilepath, newFilepath in
        guard let oldFilepath, let newFilepath else {
            return
        }

        _default.moveCallbacks.values.forEach { $0(String(cString: oldFilepath), String(cString: newFilepath)) }
    }

    /// The default notifier instance. Use this to interact with the notifier.
    public class var `default`: Notifier {
        get {
            return _default
        }
    }

    private init() {
        let result = notifier_init()
        if result != 0 {
            print("Failed to initialize notifier")
        }
        else {
            set_callback(onFileCreated, FileSystemEvent.create.rawValue)
            set_callback(onFileDeleted, FileSystemEvent.delete.rawValue)
            set_callback(onFileModified, FileSystemEvent.modify.rawValue)
            set_move_callback(onFileMoved)

            start_notifier()
        }
    }

    /// Add a notifier for specific events from a given path.
    /// - Parameters:
    /// for: The path to watch for events.
    /// events: The events to watch for.
    /// - Throws: NotifierError.failedToAddNotifier if the notifier could not be added.
    public func addNotifier(for path: String, events: [FileSystemEvent]) throws {
        let eventMask = events.reduce(0) { $0 | $1.rawValue }
        let watchId = add_watch(path, eventMask);

        guard watchId != -1 else {
            throw NotifierError.failedToAddNotifier
        }

        self.watches[path] = watchId
    }

    /// Remove a notifier for a given path.
    /// - Parameters:
    /// for: The path to remove the notifier for.
    /// - Throws: NotifierError.failedToRemoveNotifier if the notifier could not be removed.
    public func removeNotifier(for path: String) throws {
        guard let watchId = self.watches[path] else {
            throw NotifierError.failedToRemoveNotifier
        }

        guard remove_watch(watchId) != 0 else {
            throw NotifierError.failedToRemoveNotifier
        }

        self.watches.removeValue(forKey: path)
    }

    /// Add a callback to be called when a file is created.
    /// - Parameters:
    /// callback: The callback to be called when a file is created. The callback takes the path of the created file as a parameter.
    /// - Returns: A UUID that can be used to remove the callback.
    @discardableResult
    public func addOnFileCreateCallback(_ callback: @escaping (String) -> Void) -> UUID {
        let callbackIdentifier = UUID()
        self.createCallbacks[callbackIdentifier] = callback

        return callbackIdentifier
    }

    /// Add a callback to be called when a file is deleted.
    /// - Parameters:
    /// callback: The callback to be called when a file is deleted. Takes callback takes the path of the deleted file as an argument.
    /// - Returns: A UUID that can be used to remove the callback.
    @discardableResult
    public func addOnFileDeleteCallback(_ callback: @escaping (String) -> Void) -> UUID {
        let callbackIdentifier = UUID()
        self.deleteCallbacks[callbackIdentifier] = callback

        return callbackIdentifier
    }

    /// Add a callback to be called when a file is modified.
    /// - Parameters:
    /// callback: The callback to be called when a file is modified. The callback takes the path of the modified file as an argument.
    /// - Returns: A UUID that can be used to remove the callback.
    @discardableResult
    public func addOnFileModifyCallback(_ callback: @escaping (String) -> Void) -> UUID {
        let callbackIdentifier = UUID()
        self.modifyCallbacks[callbackIdentifier] = callback

        return callbackIdentifier
    }

    /// Add a callback to be called when a file is moved.
    /// - Parameters:
    /// callback: The callback to be called when a file is moved. The callback takes the old path and the new path of the moved file as arguments.
    /// - Returns: A UUID that can be used to remove the callback.
    @discardableResult
    public func addOnFileMoveCallback(_ callback: @escaping (String, String) -> Void) -> UUID {
        let callbackIdentifier = UUID()
        self.moveCallbacks[callbackIdentifier] = callback

        return callbackIdentifier
    }

    public func removeCallback(forUUID identifier: UUID) {
        self.createCallbacks.removeValue(forKey: identifier)
        self.deleteCallbacks.removeValue(forKey: identifier)
        self.modifyCallbacks.removeValue(forKey: identifier)
        self.moveCallbacks.removeValue(forKey: identifier)
    }
}