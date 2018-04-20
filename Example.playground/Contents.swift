//: Playground - noun: a place where people can play

import TaskQueue
import Foundation
import Dispatch
import PlaygroundSupport
PlaygroundPage.current.needsIndefiniteExecution = true



extension String: Swift.Error {}

struct Foo {
    private let name: String
    init(name: String) {
        self.name = name
    }
    func name(completion: @escaping (String?, Swift.Error?)->()) {
        DispatchQueue.global().async { completion(self.name, nil) }
    }
    func name(prefix: String, completion: @escaping (String?, Swift.Error?)->()) {
        DispatchQueue.global().async {
            completion( "\(prefix)\(self.name)", nil)
        }
    }
    func name(prefix: String, suffix: String, completion: @escaping (String?, Swift.Error?)->()) {
        DispatchQueue.global().async {
            completion( "\(prefix)\(self.name)\(suffix)", nil)
        }
    }
}

let f1: (@escaping (String?, Swift.Error?)->()) -> () = Foo.name(Foo(name: "Hello World!"))
let f2: (_ prefix: String, @escaping (String?, Swift.Error?)->()) -> () = Foo.name(Foo(name: "World!"))

let myTaskQueue = TaskQueue(maxConcurrentTasks: 1)


myTaskQueue.enqueue(task: f1) { s, error in
    print(s ?? "nil")
}
myTaskQueue.enqueue(task: Foo(name: "Buzz").name(completion:)) { s, error in
    print(s ?? "nil")
}
myTaskQueue.enqueue(task: Foo(name: "World!").name(prefix:completion:), "Hello ") { s, error in
    print(s ?? "nil")
}
myTaskQueue.enqueue(task: Foo(name: "World").name(prefix:suffix:completion:), "Hello ", "!") { s, error in
    print(s ?? "nil")
}



// URL Get

func get(_ url: URL) -> (_ completion: @escaping ((Data?, URLResponse?, Error?)) -> ()) -> () {
    return { completion in
        URLSession.shared.dataTask(with: url) { data, response, error in
            completion((data, response, error))
        }.resume()
    }
}

let taskQueue = TaskQueue(maxConcurrentTasks: 4)
let urlString = "https://www.example.com"
guard let url = URL(string: urlString) else {
    fatalError("URL not valid")
}

taskQueue.enqueue(task: get(url)) { (data, response, error) in
    guard error == nil, let data = data else {
        print(String(describing: error ?? "data is nil"))
        return
    }
    let html = String(data: data, encoding: .utf8) ?? ""
    print(html)
}

