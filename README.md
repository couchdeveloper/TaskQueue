# TaskQueue

[![GitHub license](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](http://www.apache.org/licenses/LICENSE-2.0) [![Swift 3.0](https://img.shields.io/badge/Swift-3.0-orange.svg?style=flat)](https://developer.apple.com/swift/) ![Platforms MacOS | iOS | tvOS | watchOS](https://img.shields.io/badge/Platforms-OS%20X%20%7C%20iOS%20%7C%20tvOS%20%7C%20watchOS-brightgreen.svg) [![Carthage Compatible](https://img.shields.io/badge/Carthage-Compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)

A `TaskQueue` is basically a FIFO queue where _tasks_ can be enqueued for execution. The tasks will be executed concurrently up to an allowed maximum number.

A _task_ is simply a non-throwing asynchronous function with a single parameter which is a completion handler called when the task finished.


## Features
 - Employs the execution of asynchronous "non-blocking" tasks.
 - The maximum number of concurrently executing tasks can be set, even during
  the execution of tasks.
 - Employs a "barrier" task which serves as a synchronization point which allows
  you to "join" all previous enqueued tasks.
 - Task and TaskQueue can be a used as a replacement for `NSOperation` and
  `NSOperationQueue`.

----------------------------------------


## Usage

First, you need a _task_, that is a function, which executes asynchronously and
which returns its result via a completion handler. You can use any type of
"Result", for example a tuple `(Value?, Error?)` or more handy types like
`Result<T>` or `Try<T>`. It is assumed, that the task function executes some
operation on a worker thread which calls the completion handler when it completes.

```Swift
func myTask(completion: (String?, Error?)->()) {
    ...
}
```

 Now, create a task queue where you can _enqueue_ a number of those tasks. You
 can control the number of maximum concurrently executing tasks in the initializer:

```Swift
 let taskQueue = TaskQueue(maxConcurrentTasks: 1)
 // Create 8 tasks and let them run:
 (0...8).forEach { _ in
   taskQueue.enqueue(task: myTask) { (String?, Error?) in
      ...
   }   
 }
```
Note, that the start of a task will be delayed up until the current number of
running tasks is below the allowed maximum number of concurrent tasks.

In the above code, the asynchronous tasks are effectively serialized, since the
maximum number of concurrent tasks is set to `1`.


### Using a barrier

A _barrier function_ allows you to create a synchronization point within the `TaskQueue`.
When the `TaskQueue` encounters a barrier function, it delays the execution of the
barrier function and any further tasks until all tasks enqueued before the barrier
have been completed. At that point, the barrier function executes exclusively. Upon
completion, the `TaskQueue` resumes its normal execution behavior.

```Swift
 let taskQueue = TaskQueue(maxConcurrentTasks: 4)
 // Create 8 tasks and let them run (max 4 will run concurrently):
 (0...8).forEach { _ in
   taskQueue.enqueue(task: myTask) { (String?, Error?) in
      ...
   }   
 }
 taskQueue.enqueueBarrier {
   // This will execute exclusively on the task queue after all previously
   // enqueued tasks have been completed.
   print("All tasks finished")
 }

 // enqueue further tasks as you like
```


### Specify a Dispatch Queue Where to Start the Task

Even though, a task _should_ always be designed such, that it is irrelevant on
which thread it will be called, the practice is often different. Fortunately, you
can specify a dispatch queue in function `enqueue` where the task will be eventually
started by the task queue, if there should be such a limitation.

If a queue is not specified, the task will be started on the global queue (`DispatchQueue.global()`).

```Swift
taskQueue.enqueue(task: myTask, queue: DispatchQueue.main) { Result<String> in
    ...
}
```

Note, that this affects only where the task will be _started_. The completion handler
will be executed on whatever thread or dispatch queue the task is choosing when it
completes. There's no way in `TaskQueue` to specify the execution context for the
completion handler.


### Constructing a Suitable Task Function from Any Other Asynchronous Function

The function signature for `enqueue` requires that you pass a _task function_ which
has a single parameter `completion` and returns `Void`. The single parameter is
the completion handler, that is a function, taking a single parameter or a tuple
`result` and returning `Void`.

So, what if your asynchronous function does not have this signature, for example,
has additional parameters and even returns a result?

Take a look at this asynchronous function from `URLSession`:
```Swift
dataTask(with url: URL,
  completionHandler: @escaping (Data?, URLResponse?, Error?) -> Swift.Void)
  -> URLSessionDataTask
```

Here, besides the completion handler we have an additional parameter `url` which
is used to _configure_ the task. It also has a return value, the created `URLSessionTask`
object.

In order to use this function with `TaskQueue`, we need to ensure that the task is
configured at the time we enqueue it, and that it has the right signature. We can
accomplish this both by applying _currying_ to the given function.

The basic steps are as follows:

Given any asynchronous function with one or more additional parameters and possibly
a return value:
```Swift
func asyncFoo(param: T, completion: @escaping (Result)->()) -> U {
  ...
}

```

we transform it to:

```Swift
func task(param: T) -> (_ completion: @escaping (Result) -> ()) -> () {
  return { completion in
    let u = asyncFoo(param: param) { result in
      completion(result)
    }
    // handle return value from asyncFoo, if any.
  }
}
```
That is, we transform the above function `asyncFoo` into another, whose parameters
consist only of the configuring parameters, and returning a _function_ having the
single remaining parameter, the completion handler, e.g. `((Result) -> ()) -> ()`.

The signature of this returned function must be valid for the task function
required by `TaskQueue`. "Result" can be a single parameter, e.g. `Result<T>` or
any tuple, e.g. `(T?, Error?)` or `(T?, U?, Error?)`, etc.

Note, that any return value from the original function (here `asyncFoo`), if any,
will be ignored by the task queue. It should be handled by the implementation of
the task function, though.

You might want to examine this snippet a couple of times to get used to it  ;)

Then use it as follows:

```Swift
taskQueue.enqueue(task: task(param: "Param")) { result in
    // handle result
    ...
}
```

This ensures, that the task will be "configured" with the given parameters at the
time it will be enqueued. The execution, though, will be delayed up until the task
queue is ready to execute it.



### Example

Here, we wrap a `URLSessionTask` executing a "GET" into a _task_ function:

```Swift
func get(_ url: URL) -> (_ completion: @escaping (Data?, URLResponse?, Error?) -> ()) -> () {
    return { completion in
        URLSession.shared.dataTask(with: url) { data, response, error in
            completion(data, response, error)
        }.resume()
    }
}
```
Then use it as follows:

```Swift
let taskQueue = TaskQueue(maxConcurrentTasks: 4)
taskQueue.enqueue(task: get(url)) { data, response, error in
    // handle (data, response, error)
    ...
}
```
