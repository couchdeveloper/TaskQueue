//: [Previous](@previous)

import TaskQueue
import Foundation
import PlaygroundSupport
PlaygroundPage.current.needsIndefiniteExecution = true

// Clientside representation of an acccess token
enum AccessToken {
    case unknown, expired
}
var _accessToken = AccessToken.unknown
func getAccessToken() -> AccessToken {
    return syncQueue.sync {
        return _accessToken
    }
}
func setAccessToken(_ accessToken: AccessToken) {
    syncQueue.sync {
        _accessToken = accessToken
    }
}

// Serveride algorithm to check if access token is expired
var _expirationDate = Date().addingTimeInterval(0.8)
func getServerSideAccessTokenIsValid() -> Bool {
    return syncQueue.sync {
        let valid = Date().compare(_expirationDate) == .orderedAscending
        return valid
    }
}
func refreshServerSideAccessToken() {
    syncQueue.sync {
        _expirationDate = Date().addingTimeInterval(30)
    }
}


let syncQueue = DispatchQueue(label: "sync_queue")



// Request the client must perform to get a new access token
func refreshTokenRequest(completion: @escaping ((AccessToken?, Swift.Error?)) -> ()) {
    let accessToken = getAccessToken()
    if accessToken != .expired {
        //print("refresh token request not started due to access token is not expired")
        DispatchQueue.global().async {
            completion((.unknown, nil))
        }
        return
    }
    print("start refresh token request")
    DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
        print("completed refresh token request")
        refreshServerSideAccessToken()
        completion((.unknown, nil))
    }
}

enum RequestError: Swift.Error {
    case accessTokenExpired
}

// Fetch a protected resource which require authentication
func resourceRequest(_ url: String) -> (_ completion: @escaping ((String?, Error?)) -> ()) -> () {
    return { completion in
        if getAccessToken() == .expired {
            //print("[\(url)] resource request not started due to access token expired")
            completion((nil, RequestError.accessTokenExpired))
            return
        }
        //print("[\(url)] start resource request")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
            if getServerSideAccessTokenIsValid() {
                //print("[\(url)] completed resource request (succeeded)")
                completion(("[\(url)] Success", nil))
            } else {
                //print("[\(url)] completed resource request (failed due to access token expired)")
                completion((nil, RequestError.accessTokenExpired))
            }
        }
    }
}



// A TaskQueue where all network request will be enqueued. It's the target queue of all other queues.
let sessionQueue = TaskQueue(maxConcurrentTasks: 4)

// A TaskQueue where resource request will be enqueued.
let requestQueue = TaskQueue(maxConcurrentTasks: 4, targetQueue: sessionQueue)

// A TaskQueue where resource requests will be enqueued which previously failed
// do to an expired access token.
let retryQueue = TaskQueue(maxConcurrentTasks: 4, targetQueue: sessionQueue)

// A TaskQueue where the refresh token request will be enqueued.
let refreshTokenRequestQueue = TaskQueue(maxConcurrentTasks: 1)

// Enqueues a number of resource requests. If a request fails due to an expired
// access token, the request will be put into the suspended retry queue, the request
// queue will be suspended and a refresh token request will be performed. When this
// finished, the retry queue and the resource queue will be resumed again which
// continues to start the enqueued requests.
func enqueueResourceRequests(urls: [String]) {
    for i in urls {
        print("Enqueue resource request \(i)")
        let task = resourceRequest(String(describing: i))
        let completion: ((String?, Error?)) -> () = { result in
            print("[\(i)] completed resource request with result: \(result)")
        }
        requestQueue.enqueue(task: task) { result in
            switch result.1 {
            case let error as RequestError where error == .accessTokenExpired:
                setAccessToken(AccessToken.expired)
                retryQueue.suspend()
                requestQueue.suspend()
                //print("Enqueue resource retry request \(i)")
                retryQueue.enqueue(task: task, completion: completion)
                refreshTokenRequestQueue.enqueue(task: refreshTokenRequest) { result in
                    defer {
                        retryQueue.enqueue(task: { (Void) -> () in
                            requestQueue.resume()
                        }, completion: {})
                        retryQueue.resume()
                    }
                    guard let accessToken = result.0 else {
                        return
                    }
                    setAccessToken(accessToken)
                }
            default:
                completion(result)
            }
        }
    }
}



// Define some "urls" and enqueue them:
let urls = (0..<32).map { "\($0)" }
enqueueResourceRequests(urls: urls)

//: [Next](@next)
