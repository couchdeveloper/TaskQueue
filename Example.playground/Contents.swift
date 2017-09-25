//: Playground - noun: a place where people can play

import TaskQueue
import Foundation
import PlaygroundSupport
PlaygroundPage.current.needsIndefiniteExecution = true


extension String: Swift.Error {}

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
