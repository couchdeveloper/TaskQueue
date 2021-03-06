//
//  TaskQueue.swift
//
//  Copyright © 2017 Andreas Grosam. All rights reserved.
//

import Dispatch


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

    private let _queue: DispatchQueue
    private var _maxConcurrentTasks: UInt = 1
    private var _concurrentTasks: UInt = 0
    private let _group = DispatchGroup()
    private let _syncQueue = DispatchQueue(label: "task_queue.sync_queue")
    public private(set) var targetQueue: TaskQueue?


    /// Designated initializer.
    ///
    /// - Parameter maxConcurrentTasks: The number of tasks which can be executed concurrently.
    public init(maxConcurrentTasks: UInt = 1, targetQueue: TaskQueue? = nil) {
        self._queue = DispatchQueue(label: "task_queue.queue", target: _syncQueue)
        _maxConcurrentTasks = maxConcurrentTasks
        self.targetQueue = targetQueue
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
    public final func enqueue<T>(task: @escaping (@escaping (T)->())->(), queue q: DispatchQueue = DispatchQueue.global(), completion: @escaping (_ result: T)->()) {
        self._queue.async {
            self.execute(task: { c in q.async {task(c)} } ) { result in
                completion(result)
            }
        }
    }


    /// Executes the given task and returns immediately.
    ///
    /// - Parameters:
    ///   - task: The task which will be enqueued.
    ///   - queue: The dispatch queue where the task should be started.
    ///   - completion: The completion handler that will be executed when the task completes.
    private final func execute<T>(task: @escaping (@escaping (T)->())->(), completion: @escaping (T)->()) {
        assert(_concurrentTasks < _maxConcurrentTasks)
        _concurrentTasks += 1
        if _concurrentTasks == _maxConcurrentTasks {
            self._queue.suspend()
        }
        self._group.enter()
        let _completion: (T)->() = { result in
            self._syncQueue.async {
                if self._concurrentTasks == self._maxConcurrentTasks {
                    self._queue.resume()
                }
                self._concurrentTasks -= 1
                self._group.leave()
            }
            completion(result)
        }
        if let targetQueue = self.targetQueue {
            targetQueue.enqueue(task: task, completion: _completion)
        } else {
            task(_completion)
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
    public final func enqueueBarrier(queue q: DispatchQueue = DispatchQueue.global(), f: @escaping ()->()) {
        //print("enqueue barrier")
        func barrier(_ completion: (())->()) {
            self._queue.suspend()
            self._group.notify(queue: q) {
                f()
                self._syncQueue.async {
                    self._queue.resume()
                }
            }
            completion(())
        }
        self._queue.async {
            self.execute(task: barrier, completion: {})
        }
    }


    /// Sets or returns the number of concurrently executing tasks.
    public final var maxConcurrentTasks: UInt {
        get {
            var result: UInt = 0
            _syncQueue.sync {
                result = self._maxConcurrentTasks
            }
            return result
        }
        set (value) {
            _syncQueue.async {
                self._maxConcurrentTasks = value
            }
        }
    }


    /// Returns the number of tasks currently running.
    public final var countRunningTasks: UInt {
        return _syncQueue.sync {
            return self._concurrentTasks
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
        self._queue.suspend()
    }

    /// Resumes the invokation of pending tasks.
    ///
    /// Calling this function will decrement an internal suspension counter, while
    /// calling `suspend()` will increment it. While this counter is greater than
    /// zero the task queue remains suspended. Only when this counter will become
    /// zero the task queue will resume its operation and start pending tasks.
    public final func resume() {
        self._queue.resume()
    }

}


