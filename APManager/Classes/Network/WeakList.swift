//
//  WeakList.swift
//  APManager
//
//  Created by Tony Clark on 2019/12/24.
//

import Foundation

public class WeakList<T>: Sequence {
    private let hashTable = NSHashTable<AnyObject>.weakObjects()
    
    func append(_ element: T) -> Void {
        hashTable.add(element as AnyObject)
    }
    
    func remove(_ element: T) -> Void {
        hashTable.remove(element as AnyObject)
    }
    
    var count: Int {
        return hashTable.count
    }
    
    public func makeIterator() -> Array<T>.Iterator {
        let allObjects = hashTable.allObjects.compactMap { $0 as? T }
        return allObjects.makeIterator()
    }
}
