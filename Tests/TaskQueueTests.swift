//
//  TaskQueueTests.swift
//  TaskQueueTests
//
//  Created by Andreas Grosam on 14.04.17.
//  Copyright © 2017 Andreas Grosam. All rights reserved.
//

import XCTest
import Dispatch
import Foundation
@testable import TaskQueue


func task(id: Int, delay: Double = 1.0) -> (_ completion: @escaping (Int) -> ()) -> () {
    return { completion in
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
            completion(id)
        }
    }
}

class TaskQueueTests: XCTestCase {

    func testEnqueuedTaskWillComplete1() {
        let taskQueue = TaskQueue()
        let expect = expectation(description: "completed")
        taskQueue.enqueue(task: task(id: 1)) {id in
            XCTAssertEqual(1, id)
            expect.fulfill()
        }
        waitForExpectations(timeout: 1)
    }


    func testEnqueuedTaskWillComplete2() {
        let taskQueue = TaskQueue()
        let expect1 = expectation(description: "completed 1")
        let expect2 = expectation(description: "completed 2")
        taskQueue.enqueue(task: task(id: 1)) { id in
            XCTAssertEqual(1, id)
            expect1.fulfill()
        }
        taskQueue.enqueue(task: task(id: 2)) { id in
            XCTAssertEqual(2, id)
            expect2.fulfill()
        }
        waitForExpectations(timeout: 10)
    }


    func ensureMaxConcurrentTasks(taskQueue: TaskQueue, numberTasks: Int, maxConcurrentTasks: UInt) {
        let sem = DispatchSemaphore(value: Int(maxConcurrentTasks))
        let syncQueue = DispatchQueue(label: "sync_queue")
        var actualMaxConcurrentTasks: Int = 0

        func task(id: Int) -> (_ completion: @escaping (Int) -> ()) -> () {
            return { completion in
                if case .timedOut = sem.wait(timeout: .now()) {
                    XCTFail("semaphore overuse")
                }
                syncQueue.sync {
                    actualMaxConcurrentTasks = max(actualMaxConcurrentTasks, Int(taskQueue.countRunningTasks))
                }
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
                    sem.signal()
                    completion(id)
                }
            }
        }

        (1...numberTasks).forEach { id in
            let expect = expectation(description: "completed")
            taskQueue.enqueue(task: task(id: id), completion: { _ in
                expect.fulfill()
            })
        }
        waitForExpectations(timeout: 10)
        XCTAssertEqual(maxConcurrentTasks, UInt(actualMaxConcurrentTasks))
    }


    func testMaxConcurrentTasks1() {
        let maxConcurrentTasks: UInt = 1
        let taskQueue = TaskQueue(maxConcurrentTasks: maxConcurrentTasks)
        ensureMaxConcurrentTasks(taskQueue: taskQueue, numberTasks: 8, maxConcurrentTasks: maxConcurrentTasks)
    }


    func testMaxConcurrentTasks2() {
        let maxConcurrentTasks: UInt = 2
        let taskQueue = TaskQueue(maxConcurrentTasks: maxConcurrentTasks)
        ensureMaxConcurrentTasks(taskQueue: taskQueue, numberTasks: 16, maxConcurrentTasks: maxConcurrentTasks)
    }


    func testMaxConcurrentTasks3() {
        let maxConcurrentTasks: UInt = 3
        let taskQueue = TaskQueue(maxConcurrentTasks: maxConcurrentTasks)
        ensureMaxConcurrentTasks(taskQueue: taskQueue, numberTasks: 24, maxConcurrentTasks: maxConcurrentTasks)
    }


    func ensureBarrier(maxConcurrentTasks: UInt , before: Int, after: Int) {
        let syncQueue = DispatchQueue(label: "snyc_queue")
        var expectedSequence: [Int] = (0..<before).map { _ in 0} + [1] + (0..<after).map { _ in 2}
        let expect = expectation(description: "barrier")
        let taskQueue = TaskQueue(maxConcurrentTasks: maxConcurrentTasks)
        func task(tag: Int) -> (_ completion: @escaping (Int) -> ()) -> () {
            return { completion in
                syncQueue.asyncAfter(deadline: .now() + 0.1) {
                    guard let x = expectedSequence.first else {
                        XCTFail("out of sequence")
                        completion(-1)
                        return
                    }
                    expectedSequence = Array(expectedSequence.dropFirst())
                    XCTAssertEqual(tag, x)
                    completion(x)
                }
            }
        }

        (1...before).forEach { id in
            let expect = expectation(description: "completed")
            taskQueue.enqueue(task: task(tag: 0), queue: syncQueue, completion: { _ in
                expect.fulfill()
            })
        }
        // When all "before" tasks finished, signal the sem:
        taskQueue.enqueueBarrier(queue: syncQueue) {
            guard let x = expectedSequence.first else {
                XCTFail("out of sequence")
                return
            }
            expectedSequence = Array(expectedSequence.dropFirst())
            XCTAssertEqual(1, x)
            sleep(1)
            expect.fulfill()
        }
        (1...after).forEach { id in
            let expect = expectation(description: "completed")
            taskQueue.enqueue(task: task(tag: 2), completion: { _ in
                expect.fulfill()
            })
        }
        waitForExpectations(timeout: 10)
    }


    func testBarrier1() {
        ensureBarrier(maxConcurrentTasks: 1, before: 4, after: 4)
    }


    func testBarrier2() {
        ensureBarrier(maxConcurrentTasks: 2, before: 8, after: 8)
    }


    func testBarrier3() {
        ensureBarrier(maxConcurrentTasks: 3, before: 12, after: 12)
    }


    func testBarrier4() {
        ensureBarrier(maxConcurrentTasks: 4, before: 16, after: 16)
    }


    func testChangeMaxConcurrentTasks() {
        let taskQueue = TaskQueue(maxConcurrentTasks: 1)
        ensureMaxConcurrentTasks(taskQueue: taskQueue, numberTasks: 4, maxConcurrentTasks: 1)
        taskQueue.enqueueBarrier {
            taskQueue.maxConcurrentTasks = 8
        }
        ensureMaxConcurrentTasks(taskQueue: taskQueue, numberTasks: 32, maxConcurrentTasks: 8)
    }

    func testSuspendedTaskQueueDelaysExecutionOfTasks1() {
        let taskQueue = TaskQueue(maxConcurrentTasks: 1)
        taskQueue.suspend()
        let sem = DispatchSemaphore(value: 0)
        taskQueue.enqueue(task: task(id: 0, delay: 0.1)) { id in
            sem.signal()
        }
        XCTAssertTrue(sem.wait(timeout: .now() + 0.5) == .timedOut)
        taskQueue.resume()
        XCTAssertFalse(sem.wait(timeout: .now() + 0.5) == .timedOut)
    }

    func testSuspendedTaskQueueDelaysExecutionOfTasks2() {
        let taskQueue = TaskQueue(maxConcurrentTasks: 8)
        taskQueue.suspend()
        let sem = DispatchSemaphore(value: 0)
        for i in 0..<8 {
            taskQueue.enqueue(task: task(id: i, delay: 0)) { _ in }
        }
        taskQueue.enqueueBarrier {
            sem.signal()
        }
        XCTAssertTrue(sem.wait(timeout: .now() + 0.5) == .timedOut)
        taskQueue.resume()
        XCTAssertFalse(sem.wait(timeout: .now() + 0.5) == .timedOut)
    }

    func testSuspendedTaskQueueDelaysExecutionOfTasks3() {
        let taskQueue = TaskQueue(maxConcurrentTasks: 8)
        taskQueue.suspend()
        taskQueue.suspend()
        taskQueue.suspend()
        let sem = DispatchSemaphore(value: 0)
        for i in 0..<8 {
            taskQueue.enqueue(task: task(id: i, delay: 0)) { _ in }
        }
        taskQueue.enqueueBarrier {
            sem.signal()
        }
        XCTAssertTrue(sem.wait(timeout: .now() + 0.5) == .timedOut)
        taskQueue.resume()
        XCTAssertTrue(sem.wait(timeout: .now() + 0.5) == .timedOut)
        taskQueue.resume()
        XCTAssertTrue(sem.wait(timeout: .now() + 0.5) == .timedOut)
        taskQueue.resume()
        XCTAssertFalse(sem.wait(timeout: .now() + 0.5) == .timedOut)
    }


    func testSuspendedTaskQueueDelaysExecutionOfTasks4() {
        let taskQueue = TaskQueue(maxConcurrentTasks: 8)
        let sem = DispatchSemaphore(value: 0)
        taskQueue.enqueueBarrier {
            taskQueue.suspend()
        }
        for i in 0..<8 {
            taskQueue.enqueue(task: task(id: i, delay: 0)) { _ in }
        }
        taskQueue.enqueueBarrier {
            sem.signal()
        }
        XCTAssertTrue(sem.wait(timeout: .now() + 0.5) == .timedOut)
        taskQueue.resume()
        XCTAssertFalse(sem.wait(timeout: .now() + 0.5) == .timedOut)
    }

}
