import Foundation

extension CFArray: Sequence {
    public func makeIterator() -> Iterator {
        return Iterator(self)
    }

    public struct Iterator: IteratorProtocol {
        var array: NSArray
        var idx = 0

        init(_ array: CFArray){
            self.array = array as NSArray
        }

        public mutating func next() -> Any? {
            guard idx < array.count else { return nil }
            let value = array[idx]
            idx += 1
            return value
        }
    }
}
