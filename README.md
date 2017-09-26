# TaskQueue

[![Build Status](https://travis-ci.org/couchdeveloper/TaskQueue.svg?branch=master)](https://travis-ci.org/couchdeveloper/TaskQueue) [![GitHub license](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](http://www.apache.org/licenses/LICENSE-2.0) [![Swift 4](https://img.shields.io/badge/Swift-4-orange.svg?style=flat)](https://developer.apple.com/swift/) ![Platforms MacOS | iOS | tvOS | watchOS](https://img.shields.io/badge/Platforms-OS%20X%20%7C%20iOS%20%7C%20tvOS%20%7C%20watchOS-brightgreen.svg) [![Carthage Compatible](https://img.shields.io/badge/Carthage-Compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage) [![CocoaPods](https://img.shields.io/badge/CocoaPods-available-370301.svg)](https://cocoapods.org/?q=cdTaskQueue)

A `TaskQueue` is basically a FIFO queue where _tasks_ can be enqueued for execution. The tasks will be executed concurrently up to an allowed maximum number.

A _task_ is simply a non-throwing asynchronous function with a single parameter
which is a completion handler called when the task finished.

## Features
 - Employs the execution of asynchronous "non-blocking" tasks.
 - The maximum number of concurrently executing tasks can be set, even during  the execution of tasks.
 - Employs a "barrier" task which serves as a synchronisation point which allows
  you to "join" all previous enqueued tasks.
 - Task and TaskQueue can be a used as a replacement for `NSOperation` and
  `NSOperationQueue`.

----------------------------------------

## Description

With a _TaskQueue_ we can control the maximum number of concurrent tasks that run "within" the task queue. In order to accomplish this, we _enqueue_  tasks into the task queue. If the actual number of running tasks is less than the maximum, the enqueued task will be immediately executed. Otherwise it will be delayed up until enough previously enqueued tasks have been completed.

At any time, we can enqueue further tasks, while the maximum number of running tasks is continuously guaranteed. Furthermore, at any time, we can change the number of maximum concurrent tasks and the task queue will adapt until the constraints are fulfilled.


## Installation

> **Note:**   
> Swift 4.0, 3.2 and 3.1 requires slightly different syntax:      
  For Swift 4 use version >= 0.9.0.   
  For Swift 3.2 compatibility use version 0.8.0 and for Swift 3.1 use version 0.7.0.

### [Carthage](https://github.com/Carthage/Carthage)

Add    
```Ruby
github "couchdeveloper/TaskQueue"
```
to your Cartfile. This is appropriate for use with Swift 4, otherwise specify version constraints as noted above.		

In your source files, import the library as follows
```Swift
import TaskQueue
```



### [CocoaPods](https://guides.cocoapods.org/using/using-cocoapods.html)

Add the following line to your [Podfile](http://guides.cocoapods.org/using/the-podfile.html):

```ruby
pod 'cdTaskQueue'
```
 This is appropriate for use with Swift 4, otherwise specify version constraints as noted above.		

In your source files, import the library as follows
```Swift
import cdTaskQueue
```

### [SwiftPM](https://github.com/apple/swift-package-manager/tree/master/Documentation)

To use SwiftPM, add this to your Package.swift:

```Swift
.Package(url: "https://github.com/couchdeveloper/TaskQueue.git")
```


## Usage

Suppose, there one or more asynchronous _tasks_ and we want to execute them in
some controlled manner. In particular, we want to make guarantees that no more
than a set limit of those tasks execute concurrently. For example, many times,
we just want to ensure, that only one task is running at a time.

Furthermore, we want to be notified when _all_  tasks of a certain set have been
completed and then take further actions, for example, based on the results,
enqueue further tasks.

### So, what's a _task_ anyway?

A _task_ is a Swift function or closure, which executes _asynchronously_ returns
`Void` and has a _single_ parameter, the completion handler. The completion handler has a single parameter where the eventual `Result` - which is computed by the underlying operation - will be passed when the task completes.

We can use any type of "Result", for example a tuple `(Value?, Error?)` or more
handy types like `Result<T>` or `Try<T>`.

**Canonical task function:**

```Swift
func task(completion: @escaping (R)->()) {
    ...
}
```
where `R` is for example: `(T?, Error?)` or `Result<T>` or `(Data?, Response?, Error?)` etc.

Note, that the type `R` may represent a _Swift Tuple_, for example `(T?, Error?)`, and please not that there are syntax changes in Swift 4:

> **Caution:**    
> In Swift 4 please consider the following changes regarding tuple parameters:    
If a function type has only one parameter and that parameter’s type is a tuple type, then the tuple type must be parenthesized when writing the function’s type. For example, `((Int, Int)) -> Void` is the type of a function that takes a single parameter of the tuple type ``(Int, Int)`` and doesn’t return any value. In contrast, without parentheses, ``(Int, Int) -> Void` is the type of a function that takes two Int parameters and doesn’t return any value. Likewise, because `Void` is a type alias for `()``, the function type `(Void) -> Void` is the same as `(()) -> ()` — a function that takes a single argument that is an empty tuple. These types are not the same as `() -> ()` — a function that takes no arguments.

So, this means, if the result type of the task´s completion handler  is a Swift Tuple, for example `(String?, Error?)`, that task must have the following signature:

```Swift
func myTask(completion: @escaping ((String?, Error?))->()) {
    ...
}
```


Now, create a task queue where we can _enqueue_ a number of those tasks. We
can control the number of maximum concurrently executing tasks in the initialiser:

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

In the above code, the asynchronous tasks are effectively serialised, since the
maximum number of concurrent tasks is set to `1`.


### Using a barrier

A _barrier function_ allows us to create a synchronisation point within the `TaskQueue`. When the `TaskQueue` encounters a barrier function, it delays the execution of the barrier function and any further tasks until all tasks enqueued before the barrier have been completed. At that point, the barrier function executes exclusively. Upon completion, the `TaskQueue` resumes its normal execution behaviour.

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
which thread it will be called, the practice is often different. Fortunately, we
can specify a dispatch queue in function `enqueue` where the task will be eventually started by the task queue, if there should be such a limitation.

If a queue is not specified, the task will be started on the global queue (`DispatchQueue.global()`).

```Swift
taskQueue.enqueue(task: myTask, queue: DispatchQueue.main) { Result<String> in
    ...
}
```

Note, that this affects only where the task will be _started_. The task's completion handler will be executed on whatever thread or dispatch queue the task is choosing when it completes. There's no way in `TaskQueue` to specify the execution context for the completion handler.


### Constructing a Suitable Task Function from Any Other Asynchronous Function

The function signature for `enqueue` requires that we pass a _task function_ which
has a single parameter `completion` and returns `Void`. The single parameter is
the completion handler, that is a function, taking a single parameter or a tuple
`result` and returning `Void`.

So, what if our asynchronous function does not have this signature, for example,
has additional parameters and even returns a result?

Take a look at this asynchronous function from `URLSession`:
```Swift
dataTask(with url: URL,
  completionHandler: @escaping (Data?, URLResponse?, Error?) -> Swift.Void)
  -> URLSessionDataTask
```

Here, besides the completion handler we have an additional parameter `url` which is used to _configure_ the task. It also has a return value, the created `URLSessionTask` object.

In order to use this function with `TaskQueue`, we need to ensure that the task is
configured at the time we enqueue it, and that it has the right signature. We can
accomplish both requirements by applying _currying_ to the given function.

The basic steps are as follows:

Given any asynchronous function with one or more additional parameters and possibly a return value:

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

That is, we transform the above function `asyncFoo` into another, whose parameters consist only of the configuring parameters, and returning a _function_ having the single remaining parameter, the completion handler, e.g.:

`((Result) -> ()) -> ()`.

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
func get(_ url: URL) -> (_ completion: @escaping ((Data?, URLResponse?, Error?)) -> ()) -> () {
    return { completion in
        URLSession.shared.dataTask(with: url) { data, response, error in
            completion((data, response, error))
        }.resume()
    }
}
```
Then use it as follows:

```Swift
let taskQueue = TaskQueue(maxConcurrentTasks: 4)
taskQueue.enqueue(task: get(url)) { (data, response, error) in
    // handle (data, response, error)
    ...
}
```

Having a list of urls, enqueue them all at once and execute them with the
constraints set in the task queue:

```Swift
let urls = [ ... ]
let taskQueue = TaskQueue(maxConcurrentTasks: 1) // serialise the tasks
urls.forEach {
  taskQueue.enqueue(task: get($0)) { (data, response, error) in
      // handle (data, response, error)
      ...
  }  
}
```
