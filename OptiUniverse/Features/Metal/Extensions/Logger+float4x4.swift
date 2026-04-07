//
//  Logger+float4x4.swift
//  OptiUniverse
//
//  Created by max on 23.08.2025.
//

import os
import simd
import Foundation

extension Logger {
    
    func logMatricies(matrix1: float4x4, matrix2: float4x4, caption: String?, level: OSLogType) {
        if let caption, !caption.isEmpty {
            log(level: level, "\(caption)")
        }
        log(level: level, "-------------------")
        for i in 0..<4 {
            var leftString = ""
            for j in 0..<4 {
                leftString += String(format: "%.2f ", matrix1[i, j])
            }
            var rightString = ""
            for j in 0..<4 {
                rightString += String(format: "%.2f ", matrix2[i, j])
            }
            log(level: level, "\(leftString, align: .left(columns: 30)) \(rightString)")
        }
        log(level: level, "-------------------")
    }
}
