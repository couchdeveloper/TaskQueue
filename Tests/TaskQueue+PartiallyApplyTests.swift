//
//  TaskQueue+PartiallyApplyTests.swift
//  TaskQueueTests
//
//  Created by Andreas Grosam on 12.04.18.
//  Copyright © 2018 Andreas Grosam. All rights reserved.
//

import XCTest
import Dispatch
import Foundation
import TaskQueue


func async1(arg0: Int, completion: @escaping (Int?, Swift.Error?) -> ()) {
    DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
        let result = arg0
        completion(result, nil)
    }
}

func async2(arg0: Int, arg1: Int, completion: @escaping (Int) -> ()) {
    DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
        let result = arg0 + arg1
        completion(result)
    }
}

func async3(arg0: Int, arg1: Int, arg2: Int, completion: @escaping (Int) -> ()) {
    DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
        let result = arg0 + arg1 + arg2
        completion(result)
    }
}


class TaskQueue_PartiallyApplyTests: XCTestCase {
    
    func testMakeTaskFuncFromAsyncWith1Args() {
        let taskQueue = TaskQueue()
        let expect = expectation(description: "completed")
        taskQueue.enqueue(task: async1(arg0:completion:), 1, completion: { id, error in
            XCTAssertEqual(1, id)
            expect.fulfill()
        })
        waitForExpectations(timeout: 1)
    }

//    func testMakeTaskFuncFromAsyncWith2Args() {
//        let taskQueue = TaskQueue()
//        let expect = expectation(description: "completed")
//        let task = TaskQueue.makeTask(async2(arg0:arg1:completion:), 1, 1)
//        taskQueue.enqueue(task: task) { result in
//            XCTAssertEqual(2, result)
//            expect.fulfill()
//        }
//        waitForExpectations(timeout: 1)
//    }
//
//    func testMakeTaskFuncFromAsyncWith3Args() {
//        let taskQueue = TaskQueue()
//        let expect = expectation(description: "completed")
//        let task = TaskQueue.makeTask(async3(arg0:arg1:arg2:completion:), 1, 1, 1)
//        taskQueue.enqueue(task: task) { result in
//            XCTAssertEqual(3, result)
//            expect.fulfill()
//        }
//        waitForExpectations(timeout: 1)
//    }

}
