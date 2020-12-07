//
//  TaskQueue.swift
//
//  Copyright © 2017 Andreas Grosam. All rights reserved.
//

import Dispatch

public let defaultProcessQueue = DispatchQueue(label: "com.TaskQueue.default-process-queue")

/**
 A `TaskQueue` is a FIFO queue where _tasks_ can be enqueued for execution. The
 tasks will be executed in order up to `maxConcurrentTasks` concurrently. The start
 of a task will be delayed up until the current number of running tasks is below
 the allowed maximum number of concurrent tasks.

 When a task completes it will be automatically dequeued and its completion handler
 will be called.

 The allowed maximum number of concurrent tasks can be changed while tasks are
 executing.
`
 A _task_ is simply a non-throwing asynchronous function with a single parameter
 `completion` which is a function type. The completion function has a single parameter
 which desginates the result type of the task. On completion, the task MUST call
 the completion handler passing the result. Usually, the result type is a discriminated
 union (aka Enum) which contains either a value or an error.
*/
public class TaskQueue {

    private let taskQueue: DispatchQueue
    private let group = DispatchGroup()
    private let mutex = UnfairLock() // DispatchQueue(label: "task_queue.sync_queue")
    private var _maxConcurrentTasks: UInt = 1
    private var _concurrentTasks: UInt = 0

    /// Creates and initializes a Task Queue with the given number of maximum allowed concurrent tasks.
    ///
    /// - Parameters:
    ///   - maxConcurrentTasks: The number of tasks which can be executed concurrently.
    public init(maxConcurrentTasks: UInt = 1) {
        self.taskQueue = DispatchQueue(label: "com.TaskQueue.queue")
        _maxConcurrentTasks = maxConcurrentTasks
    }

    /// Enqueues the given task and returns immediately.
    ///
    /// The task will be executed when the current number of active tasks is
    /// smaller than `maxConcurrentTasks`.
    /// - Parameters:
    ///   - task: The task which will be enqueued.
    ///   - queue: The dispatch queue where the task should be started.
    ///   - completion: The completion handler which will be executed when the task completes. It will be executed on whatever execution context the task has been choosen.
    /// - Parameters:
    ///   - result: The task's result.
    /// - Attention: There's no upper limit for the number of enqueued tasks. An enqueued task may reference resources and other objects which will be only released when the task has been completed.
    public final func enqueue<T>(task: @escaping (@escaping (T) -> Void) -> Void, queue: DispatchQueue = defaultProcessQueue, completion: @escaping (_ result: T) -> Void) {
        self.taskQueue.async {
            self.execute(task: task, processQueue: queue, completion: completion)
        }
    }

    /// Enqueues the given function for barrier execution and returns immediately.
    ///
    /// A barrier function allows you to create a synchronization point within the
    /// `TaskQueue`. When the `TaskQueue` encounters a barrier function, it delays
    /// the execution of the barrier function and any further tasks until all tasks
    /// enqueued before the barrier finish executing. At that point, the barrier
    /// function executes exclusively. Upon completion, the `TaskQueue` resumes
    /// its normal execution behavior.
    ///
    /// - Parameters:
    ///   - queue: The dispatch queue where the barrier should be executed.
    ///   - f: The barrier function.
    public final func enqueueBarrier(queue: DispatchQueue = defaultProcessQueue, f: @escaping () -> Void) {
        func task(completion: @escaping (()) -> Void) {
            f()
            completion(())
        }
        self.taskQueue.async {
            self.execute(task: task, asBarrier: true, processQueue: queue, completion: {})
        }
    }

    /// Enqueues the given task for barrier execution and returns immediately.
    ///
    /// A barrier task allows you to create a synchronization point within the
    /// `TaskQueue`. When the `TaskQueue` encounters a barrier, it delays
    /// the execution of the barrier task and any further tasks until all tasks
    /// enqueued before the barrier finish executing. At that point, the barrier
    /// task executes exclusively. Upon completion, the `TaskQueue` resumes
    /// its normal execution behavior.
    ///
    /// - Parameters:
    ///   - task: The barrier function.
    ///   - queue: The dispatch queue where the barrier should be executed.
    ///   - completion: The completion handler which will be executed when the barrier task
    ///   completes. It will be executed on whatever execution context the task has been choosen.
    public final func enqueueBarrier<T>(task: @escaping (@escaping (T) -> Void) -> Void, queue: DispatchQueue = defaultProcessQueue, completion: @escaping (_ result: T) -> Void) {
        self.taskQueue.async {
            self.execute(task: task, asBarrier: true, processQueue: queue, completion: completion)
        }
    }

    /// Sets or returns the number of concurrently executing tasks.
    public final var maxConcurrentTasks: UInt {
        get {
            return self.mutex.locked {
                _maxConcurrentTasks
            }
        }
        set (value) {
            self.mutex.locked {
                let distance = Int(value) - Int(_maxConcurrentTasks)
                _maxConcurrentTasks = value
                resumeOrSuspendIfNeeded(distance: distance)
            }
        }
    }

    /// Returns the number of tasks currently running.
    public final var countRunningTasks: UInt {
        return self.mutex.locked {
            self._concurrentTasks
        }
    }

    /// Suspends the invokation of pending tasks.
    ///
    /// When suspending a TaskQueue, pending tasks can be temporarily delayed for
    /// execution. Tasks already running will not be affected.
    /// Calling this function will increment an internal suspension counter, while
    /// calling `resume()` will decrement it. While this counter is greater than
    /// zero the task queue remains suspended.
    public final func suspend() {
        self.taskQueue.suspend()
    }

    /// Resumes the invokation of pending tasks.
    ///
    /// Calling this function will decrement an internal suspension counter, while
    /// calling `suspend()` will increment it. While this counter is greater than
    /// zero the task queue remains suspended. Only when this counter will become
    /// zero the task queue will resume its operation and start pending tasks.
    public final func resume() {
        self.taskQueue.resume()
    }

    /// Starts the asynchronous task and returns immediately.
    ///
    /// - Parameters:
    ///   - task: The task which will be executed.
    ///   - processQueue: The dispatch queue where the task should be started.
    ///   - completion: The completion handler that will be executed when the task completes.
    private final func execute<T>(task: @escaping (@escaping (T) -> Void) -> Void, asBarrier: Bool = false, processQueue: DispatchQueue, completion: @escaping (T) -> Void) {
        dispatchPrecondition(condition: .onQueue(self.taskQueue))
        assert(_concurrentTasks < _maxConcurrentTasks)

        func _enqueue() {
            self.mutex.lock()
            _concurrentTasks += 1
            resumeOrSuspendIfNeeded(distance: -1)
            self.mutex.unlock()
        }
        func _dequeue() {
            self.mutex.lock()
            self._concurrentTasks -= 1
            resumeOrSuspendIfNeeded(distance: 1)
            self.mutex.unlock()
        }
        func barrier(_ completion: @escaping (T) -> Void) {
            self.taskQueue.suspend()
            self.group.notify(queue: processQueue) {
                task() { result in
                    self.taskQueue.resume()
                    completion(result)
                }
            }
        }

        if asBarrier == false {
            _enqueue()
            self.group.enter()
            processQueue.async {
                task() { result in
                    _dequeue()
                    self.group.leave()
                    completion(result)
                }
            }
        } else {
            _enqueue()
            barrier { result in
                _dequeue()
                completion(result)
            }
        }
    }

    private func resumeOrSuspendIfNeeded(distance: Int) {
        let currentAvail = Int(_maxConcurrentTasks) - Int(_concurrentTasks)
        let formerAvail =  currentAvail - distance

        switch (formerAvail, currentAvail) {
        case (1...Int.max, Int.min...0):
            suspend()
        case (Int.min...0, 1...Int.max):
            resume()
        default:
            break
        }
    }

}
