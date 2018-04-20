//
//  TaskQueue+PartiallyApply.swift
//  TaskQueue
//
//  Created by Andreas Grosam on 12.04.18.
//  Copyright © 2018 Andreas Grosam. All rights reserved.
//

import Dispatch


/// Curries an unary function `f`, producing a function which can be partially applied.
fileprivate func curry<T1, R>(_ f: @escaping (T1) -> R) -> (T1) -> R {
    return f
}

/// Curries a binary function `f`, producing a function which can be partially applied.
fileprivate func curry<T1, T2, R>(_ f: @escaping (T1, T2) -> R) -> (T1) -> (T2) -> R {
    return { x in { f(x, $0) } }
}

/// Curries a ternary function `f`, producing a function which can be partially applied.
fileprivate func curry<T1, T2, T3, R>(_ f: @escaping (T1, T2, T3) -> R) -> (T1) -> (T2) -> (T3) -> R {
    return { x in curry { f(x, $0, $1) } }
}

/// Curries a quaternary function `f`, producing a function which can be partially applied.
fileprivate func curry<T1, T2, T3, T4, R>(_ f: @escaping (T1, T2, T3, T4) -> R) -> (T1) -> (T2) -> (T3) -> (T4) -> R {
    return { x in curry { f(x, $0, $1, $2) } }
}

/// Curries a quinary function `f`, producing a function which can be partially applied.
fileprivate func curry<T1, T2, T3, T4, T5, R>(_ f: @escaping (T1, T2, T3, T4, T5) -> R) -> (T1) -> (T2) -> (T3) -> (T4) -> (T5) -> R {
    return { x in curry { f(x, $0, $1, $2, $3) } }
}

/// Adds some convenience functions
public extension TaskQueue {
    /// Enqueues the partially applied task function and returns immediately.
    ///
    /// The task will be executed when the current number of active tasks is
    /// smaller than `maxConcurrentTasks`.
    ///
    /// - Parameters:
    ///   - task: The task function which will be partially applied and then enqueued.
    ///   - param1: The first argument which will be fixed to the task function.
    ///   - q: The dispatch queue where the task will be started.
    ///   - completion: The completion handler which will be executed when the task completes. It will be executed on whatever execution context the task has been choosen.
    /// - Parameters:
    ///   - result: The task's result.
    func enqueue<T1,Result>(task: @escaping (T1, @escaping (Result)->())->(), _ param1: T1, queue q: DispatchQueue = DispatchQueue.global(), completion: @escaping (_ result: Result)->()) {
        self.enqueue(task: curry(task)(param1), completion: completion)
    }

    /// Enqueues the partially applied task function and returns immediately.
    ///
    /// The task will be executed when the current number of active tasks is
    /// smaller than `maxConcurrentTasks`.
    ///
    /// - Parameters:
    ///   - task: The task function which will be partially applied and then enqueued.
    ///   - param1: The first argument which will be fixed to the task function.
    ///   - q: The dispatch queue where the task will be started.
    ///   - completion: The completion handler which will be executed when the task completes. It will be executed on whatever execution context the task has been choosen.
    /// - Parameters:
    ///   - arg0: The task result's first argument whose type equals the type parameter `ResArg0`.
    ///   - arg1: The task result's second argument whose type equals the type parameter `ResArg1`.
    func enqueue<T1,ResArg0,ResArg1>(task: @escaping (T1, @escaping (ResArg0, ResArg1)->())->(), _ param1: T1, queue q: DispatchQueue = DispatchQueue.global(), completion: @escaping (_ arg0: ResArg0, _ arg1: ResArg1)->()) {
        self.enqueue(task: curry(task)(param1), completion: completion)
    }

    /// Enqueues the partially applied task function and returns immediately.
    ///
    /// The task will be executed when the current number of active tasks is
    /// smaller than `maxConcurrentTasks`.
    ///
    /// - Parameters:
    ///   - task: The task function which will be partially applied and then enqueued.
    ///   - param1: The first argument which will be fixed to the task function.
    ///   - q: The dispatch queue where the task will be started.
    ///   - completion: The completion handler which will be executed when the task completes. It will be executed on whatever execution context the task has been choosen.
    /// - Parameters:
    ///   - arg0: The task result's first argument whose type equals the type parameter `ResArg0`.
    ///   - arg1: The task result's second argument whose type equals the type parameter `ResArg1`.
    ///   - arg2: The task result's third argument whose type equals the type parameter `ResArg2`.
    func enqueue<T1,ResArg0,ResArg1,ResArg2>(task: @escaping (T1, @escaping (ResArg0, ResArg1, ResArg2)->())->(), _ param1: T1, queue q: DispatchQueue = DispatchQueue.global(), completion: @escaping (_ arg0: ResArg0, _ arg1: ResArg1, _ arg2: ResArg2)->()){
        self.enqueue(task: curry(task)(param1), completion: completion)
    }

}

public extension TaskQueue {
    /// Enqueues the partially applied task function and returns immediately.
    ///
    /// The task will be executed when the current number of active tasks is
    /// smaller than `maxConcurrentTasks`.
    ///
    /// - Parameters:
    ///   - task: The task function which will be partially applied and then enqueued.
    ///   - param1: The first argument which will be fixed to the task function.
    ///   - param2: The second argument which will be fixed to the task function.
    ///   - q: The dispatch queue where the task will be started.
    ///   - completion: The completion handler which will be executed when the task completes. It will be executed on whatever execution context the task has been choosen.
    /// - Parameters:
    ///   - result: The task's result.
    func enqueue<T1,T2,Result>(task: @escaping (T1, T2, @escaping (Result)->())->(), _ param1: T1, _ param2: T2, queue q: DispatchQueue = DispatchQueue.global(), completion: @escaping (_ result: Result)->()) {
        self.enqueue(task: curry(task)(param1)(param2), completion: completion)
    }

    /// Enqueues the partially applied task function and returns immediately.
    ///
    /// The task will be executed when the current number of active tasks is
    /// smaller than `maxConcurrentTasks`.
    ///
    /// - Parameters:
    ///   - task: The task function which will be partially applied and then enqueued.
    ///   - param1: The first argument which will be fixed to the task function.
    ///   - param2: The second argument which will be fixed to the task function.
    ///   - q: The dispatch queue where the task will be started.
    ///   - completion: The completion handler which will be executed when the task completes. It will be executed on whatever execution context the task has been choosen.
    /// - Parameters:
    ///   - arg0: The task result's first argument whose type equals the type parameter `ResArg0`.
    ///   - arg1: The task result's second argument whose type equals the type parameter `ResArg1`.
    func enqueue<T1,T2,ResArg0,ResArg1>(task: @escaping (T1, T2, @escaping (ResArg0, ResArg1)->())->(), _ param1: T1, _ param2: T2, queue q: DispatchQueue = DispatchQueue.global(), completion: @escaping (_ arg0: ResArg0, _ arg1: ResArg1)->()) {
        self.enqueue(task: curry(task)(param1)(param2), completion: completion)
    }

    /// Enqueues the partially applied task function and returns immediately.
    ///
    /// The task will be executed when the current number of active tasks is
    /// smaller than `maxConcurrentTasks`.
    ///
    /// - Parameters:
    ///   - task: The task function which will be partially applied and then enqueued.
    ///   - param1: The first argument which will be fixed to the task function.
    ///   - param2: The second argument which will be fixed to the task function.
    ///   - q: The dispatch queue where the task will be started.
    ///   - completion: The completion handler which will be executed when the task completes. It will be executed on whatever execution context the task has been choosen.
    /// - Parameters:
    ///   - arg0: The task result's first argument whose type equals the type parameter `ResArg0`.
    ///   - arg1: The task result's second argument whose type equals the type parameter `ResArg1`.
    ///   - arg2: The task result's third argument whose type equals the type parameter `ResArg2`.
    func enqueue<T1,T2,ResArg0,ResArg1,ResArg2>(task: @escaping (T1, T2, @escaping (ResArg0, ResArg1, ResArg2)->())->(), _ param1: T1, _ param2: T2, queue q: DispatchQueue = DispatchQueue.global(), completion: @escaping (_ arg0: ResArg0, _ arg1: ResArg1, _ arg2: ResArg2)->()){
        self.enqueue(task: curry(task)(param1)(param2), completion: completion)
    }

}

public extension TaskQueue {
    /// Enqueues the partially applied task function and returns immediately.
    ///
    /// The task will be executed when the current number of active tasks is
    /// smaller than `maxConcurrentTasks`.
    ///
    /// - Parameters:
    ///   - task: The task function which will be partially applied and then enqueued.
    ///   - param1: The first argument which will be fixed to the task function.
    ///   - param2: The second argument which will be fixed to the task function.
    ///   - param3: The third argument which will be fixed to the task function.
    ///   - q: The dispatch queue where the task will be started.
    ///   - completion: The completion handler which will be executed when the task completes. It will be executed on whatever execution context the task has been choosen.
    /// - Parameters:
    ///   - result: The task's result.
    func enqueue<T1,T2,T3,Result>(task: @escaping (T1, T2, T3, @escaping (Result)->())->(), _ param1: T1, _ param2: T2, _ param3: T3, queue q: DispatchQueue = DispatchQueue.global(), completion: @escaping (_ result: Result)->()) {
        self.enqueue(task: curry(task)(param1)(param2)(param3), completion: completion)
    }

    /// Enqueues the partially applied task function and returns immediately.
    ///
    /// The task will be executed when the current number of active tasks is
    /// smaller than `maxConcurrentTasks`.
    ///
    /// - Parameters:
    ///   - task: The task function which will be partially applied and then enqueued.
    ///   - param1: The first argument which will be fixed to the task function.
    ///   - param2: The second argument which will be fixed to the task function.
    ///   - param3: The third argument which will be fixed to the task function.
    ///   - q: The dispatch queue where the task will be started.
    ///   - completion: The completion handler which will be executed when the task completes. It will be executed on whatever execution context the task has been choosen.
    /// - Parameters:
    ///   - arg0: The task result's first argument whose type equals the type parameter `ResArg0`.
    ///   - arg1: The task result's second argument whose type equals the type parameter `ResArg1`.
    func enqueue<T1,T2,T3,ResArg0,ResArg1>(task: @escaping (T1, T2, T3, @escaping (ResArg0, ResArg1)->())->(), _ param1: T1, _ param2: T2, _ param3: T3, queue q: DispatchQueue = DispatchQueue.global(), completion: @escaping (_ arg0: ResArg0, _ arg1: ResArg1)->()) {
        self.enqueue(task: curry(task)(param1)(param2)(param3), completion: completion)
    }

    /// Enqueues the partially applied task function and returns immediately.
    ///
    /// The task will be executed when the current number of active tasks is
    /// smaller than `maxConcurrentTasks`.
    ///
    /// - Parameters:
    ///   - task: The task function which will be partially applied and then enqueued.
    ///   - param1: The first argument which will be fixed to the task function.
    ///   - param2: The second argument which will be fixed to the task function.
    ///   - param3: The third argument which will be fixed to the task function.
    ///   - q: The dispatch queue where the task will be started.
    ///   - completion: The completion handler which will be executed when the task completes. It will be executed on whatever execution context the task has been choosen.
    /// - Parameters:
    ///   - arg0: The task result's first argument whose type equals the type parameter `ResArg0`.
    ///   - arg1: The task result's second argument whose type equals the type parameter `ResArg1`.
    ///   - arg2: The task result's third argument whose type equals the type parameter `ResArg2`.
    func enqueue<T1,T2,T3,ResArg0,ResArg1,ResArg2>(task: @escaping (T1, T2,T3, @escaping (ResArg0, ResArg1, ResArg2)->())->(), _ param1: T1, _ param2: T2, _ param3: T3, queue q: DispatchQueue = DispatchQueue.global(), completion: @escaping (_ arg0: ResArg0, _ arg1: ResArg1, _ arg2: ResArg2)->()){
        self.enqueue(task: curry(task)(param1)(param2)(param3), completion: completion)
    }

}



