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


    /// Designated initializer.
    ///
    /// - Parameter maxConcurrentTasks: The number of tasks which can be executed concurrently.
    public init(maxConcurrentTasks: UInt = 1) {
        self._queue = DispatchQueue(label: "task_queue.queue", target: _syncQueue)
        _maxConcurrentTasks = maxConcurrentTasks
    }


    /// Enqueues the given task and returns immediately.
    ///
    /// The task's completion handler has the signature: `(Result)->()` where
    /// `Result` usually is a `Try`, `Either` or `Result` type which is a
    /// discriminated union representing _either_ the computed value or an error.
    ///
    /// The task will be executed when the current number of active tasks is
    /// smaller than `maxConcurrentTasks`.
    /// - Parameters:
    ///   - task: The task which will be enqueued.
    ///   - queue: The dispatch queue where the task will be started.
    ///   - completion: The completion handler which will be executed when the task completes. It will be executed on whatever execution context the task has been choosen.
    /// - Parameters:
    ///   - result: The task's result.
    /// - Attention: There's no upper limit for the number of enqueued tasks. An enqueued task may reference resources and other objects which will be only released when the task has been completed.
    public final func enqueue<Result>(task: @escaping (@escaping (Result)->())->(), queue q: DispatchQueue = DispatchQueue.global(), completion: @escaping (_ result: Result)->()) {
        //print("enqueue task")
        self._queue.async {
            //print("start task")
            self.execute(task: { completion in
                q.async { task(completion) }
            }) { result in
                //print("complete task")
                completion(result)
            }
        }
    }


    /// Enqueues the given task and returns immediately.
    ///
    /// The task's completion handler has the signature: `(ResArg0, ResArg1)->()` which
    /// usually are optionals representing the computed value respevtively an error.
    ///
    /// The task will be executed when the current number of active tasks is
    /// smaller than `maxConcurrentTasks`.
    /// - Parameters:
    ///   - task: The task which will be enqueued.
    ///   - queue: The dispatch queue where the task will be started.
    ///   - completion: The completion handler which will be executed when the task completes. It will be executed on whatever execution context the task has been choosen.
    /// - Parameters:
    ///   - arg0: The task result's first argument whose type equals the type parameter `ResArg0`. Usually this is an optional representing the computed value.
    ///   - arg1: The task result's second argument whose type equals the type parameter `ResArg1`. Usually this is an optional representing an error.
    /// - Attention: There's no upper limit for the number of enqueued tasks. An enqueued task may reference resources and other objects which will be only released when the task has been completed.
    public final func enqueue<ResArg0, ResArg1>(task: @escaping (@escaping (ResArg0, ResArg1)->())->(), queue q: DispatchQueue = DispatchQueue.global(), completion: @escaping (_ arg0: ResArg0, _ arg1: ResArg1)->()) {
        //print("enqueue task")
        self._queue.async {
            //print("start task")
            func task0(completion: @escaping ((ResArg0, ResArg1))->()) {
                q.async {
                    task() { a, b in
                        completion((a,b))
                    }
                }
            }
            self.execute(task: task0(completion:)) { result in
                //print("complete task")
                completion(result.0, result.1)
            }
        }
    }


    /// Enqueues the given task and returns immediately.
    ///
    /// The task's completion handler has the signature: `(ResArg0, ResArg1, ResArg2)->()`
    /// which are usually optionals representing the computed values and an error.
    ///
    /// The task will be executed when the current number of active tasks is
    /// smaller than `maxConcurrentTasks`.
    /// - Parameters:
    ///   - task: The task which will be enqueued.
    ///   - queue: The dispatch queue where the task will be started.
    ///   - completion: The completion handler which will be executed when the task completes. It will be executed on whatever execution context the task has been choosen.
    /// - Parameters:
    ///   - arg0: The task result's first argument whose type equals the type parameter `ResArg0`.
    ///   - arg1: The task result's second argument whose type equals the type parameter `ResArg1`.
    ///   - arg2: The task result's third argument whose type equals the type parameter `ResArg2`.
    /// - Attention: There's no upper limit for the number of enqueued tasks. An enqueued task may reference resources and other objects which will be only released when the task has been completed.
    public final func enqueue<ResArg0, ResArg1, ResArg2>(task: @escaping (@escaping (ResArg0, ResArg1, ResArg2)->())->(), queue q: DispatchQueue = DispatchQueue.global(), completion: @escaping (_ arg0: ResArg0, _ arg1: ResArg1, _ arg2: ResArg2)->()) {
        //print("enqueue task")
        self._queue.async {
            //print("start task")
            func task0(completion: @escaping ((ResArg0, ResArg1, ResArg2))->()) {
                q.async {
                    task() { a, b, c in
                        completion((a,b,c))
                    }
                }
            }
            self.execute(task: task0(completion:)) { result in
                //print("complete task")
                completion(result.0, result.1, result.2)
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
        task() { result in
            self._syncQueue.async {
                if self._concurrentTasks == self._maxConcurrentTasks {
                    self._queue.resume()
                }
                self._concurrentTasks -= 1
                self._group.leave()
            }
            completion(result)
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
            //print("barrier wait for exclusive execution: number of running tasks: \(self._concurrentTasks - 1)")
            self._queue.suspend()
            self._group.notify(queue: q) {
                //print("execute barrier func")
                f()
                self._syncQueue.async {
                    //print("leave barrier")
                    self._queue.resume()
                }
            }
            completion(())
        }
        self._queue.async {
            //print("start barrier")
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


    public final var countRunningTasks: UInt {
        return _syncQueue.sync {
            return self._concurrentTasks
        }
    }


}
