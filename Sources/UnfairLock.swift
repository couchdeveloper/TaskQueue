//
//  Copyright © 2020 Andreas Grosam.
//  Licensed under the Apache License, Version 2.0.
//

import Foundation

/// A wrapper around `os_unfair_lock` which can be safely used in Swift.
///
/// - Warning: This lock must be unlocked from the same thread that locked it. Attempts to unlock from
/// a different thread will cause an assertion aborting the process.
@available(iOS 10.0, *)
@available(OSX 10.12, *)
final class UnfairLock: Mutex {
    private var _lock: UnsafeMutablePointer<os_unfair_lock>

    init() {
        _lock = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)
        _lock.initialize(to: os_unfair_lock())
    }

    deinit {
        _lock.deallocate()
    }

    func lock() {
        os_unfair_lock_lock(_lock)
    }

    func unlock() {
        os_unfair_lock_unlock(_lock)
    }

    func locked<ReturnValue>(_ f: () throws -> ReturnValue) rethrows -> ReturnValue {
        os_unfair_lock_lock(_lock)
        defer { os_unfair_lock_unlock(_lock) }
        return try f()
    }

    func assertOwned() {
        os_unfair_lock_assert_owner(_lock)
    }

    func assertNotOwned() {
        os_unfair_lock_assert_not_owner(_lock)
    }
}
