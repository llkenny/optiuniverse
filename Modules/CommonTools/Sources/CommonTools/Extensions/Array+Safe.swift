//
//  Array+Safe.swift
//  CommonTools
//
//  Created by max on 07.05.2026.
//

public extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
