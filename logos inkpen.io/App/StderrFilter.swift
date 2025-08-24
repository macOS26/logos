//
//  StderrFilter.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/23/25.
//

import Foundation
import SwiftUI
import CoreGraphics

// MARK: - Stderr Filter (Suppresses noisy system warnings)
final class StderrFilter {
    static let shared = StderrFilter()
    
    private var suppressPatterns: [String] = []
    private var originalStderrFD: Int32 = -1
    private var pipeReadFD: Int32 = -1
    private var pipeWriteFD: Int32 = -1
    private var readSource: DispatchSourceRead?
    private var pendingBuffer = Data()
    private let queue = DispatchQueue(label: "io.logos.stderr.filter", qos: .background)
    private var isInstalled = false
    
    private init() {}
    
    func installFilter(suppressing patterns: [String]) {
        guard !isInstalled else { return }
        isInstalled = true
        suppressPatterns = patterns.map { $0.lowercased() }
        
        var fds: [Int32] = [0, 0]
        if pipe(&fds) != 0 {
            return
        }
        pipeReadFD = fds[0]
        pipeWriteFD = fds[1]
        
        // Duplicate current stderr so we can still write through to it
        originalStderrFD = dup(STDERR_FILENO)
        if originalStderrFD == -1 {
            close(pipeReadFD)
            close(pipeWriteFD)
            return
        }
        
        // Make stderr unbuffered to avoid delays
        setvbuf(stderr, nil, _IONBF, 0)
        
        // Redirect stderr to our pipe
        if dup2(pipeWriteFD, STDERR_FILENO) == -1 {
            close(pipeReadFD)
            close(pipeWriteFD)
            close(originalStderrFD)
            return
        }
        // We can close our copy of the write end; STDERR now refers to it
        close(pipeWriteFD)
        
        let source = DispatchSource.makeReadSource(fileDescriptor: pipeReadFD, queue: queue)
        readSource = source
        
        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            var buffer = [UInt8](repeating: 0, count: 4096)
            let bytesRead = read(self.pipeReadFD, &buffer, buffer.count)
            if bytesRead > 0 {
                self.pendingBuffer.append(buffer, count: bytesRead)
                self.processPendingBuffer()
            } else if bytesRead == 0 {
                // EOF
                self.flushRemaining()
                self.cleanup()
            } else {
                // Read error
                self.cleanup()
            }
        }
        
        source.setCancelHandler { [weak self] in
            guard let self = self else { return }
            if self.pipeReadFD != -1 { close(self.pipeReadFD) }
        }
        
        source.resume()
    }
    
    private func processPendingBuffer() {
        // Split by newline, keep last partial in pendingBuffer
        while let range = pendingBuffer.firstRange(of: Data([0x0A])) { // '\n'
            let lineData = pendingBuffer.subdata(in: 0..<range.lowerBound)
            pendingBuffer.removeSubrange(0..<(range.upperBound)) // remove line + newline
            forwardIfNotSuppressed(lineData: lineData)
        }
    }
    
    private func flushRemaining() {
        if !pendingBuffer.isEmpty {
            forwardIfNotSuppressed(lineData: pendingBuffer)
            pendingBuffer.removeAll(keepingCapacity: false)
        }
    }
    
    private func forwardIfNotSuppressed(lineData: Data) {
        guard let line = String(data: lineData, encoding: .utf8) else {
            writeRaw(lineData)
            writeRaw(Data([0x0A]))
            return
        }
        let lower = line.lowercased()
        let shouldSuppress = suppressPatterns.contains { lower.contains($0) }
        if !shouldSuppress {
            writeRaw(lineData)
            writeRaw(Data([0x0A]))
        }
    }
    
    private func writeRaw(_ data: Data) {
        data.withUnsafeBytes { ptr in
            var remaining = ptr.count
            var base = ptr.bindMemory(to: UInt8.self).baseAddress
            while remaining > 0 {
                let written = write(originalStderrFD, base, remaining)
                if written <= 0 { break }
                remaining -= written
                base = base?.advanced(by: written)
            }
        }
    }
    
    private func cleanup() {
        readSource?.cancel()
        readSource = nil
        if originalStderrFD != -1 { close(originalStderrFD); originalStderrFD = -1 }
        if pipeReadFD != -1 { close(pipeReadFD); pipeReadFD = -1 }
        isInstalled = false
    }
}
