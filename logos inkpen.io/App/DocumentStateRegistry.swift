//
//  DocumentStateRegistry.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/23/25.
//

import SwiftUI

// MARK: - DocumentState Registry (replaces notifications)
final class DocumentStateRegistry {
    static let shared = DocumentStateRegistry()
    private let table = NSHashTable<DocumentState>.weakObjects()
    private let lock = NSLock()
    private init() {}
    func register(_ state: DocumentState) {
        lock.lock(); defer { lock.unlock() }
        table.add(state)
    }
    func forceCleanupAll() {
        lock.lock(); let states = table.allObjects; lock.unlock()
        for state in states { state.forceCleanup() }
    }
}
