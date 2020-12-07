//
//  Mutex.swift
//  TaskQueue
//
//  Created by Andreas Grosam on 04.12.20.
//  Copyright © 2020 Andreas Grosam. All rights reserved.
//

protocol Mutex {
    func lock()
    func unlock()
}
