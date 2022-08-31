//
//  COBS.swift
//  
//
//  Created by ANTROPOV Evgeny on 17.02.2022.
//

import Foundation

public extension Data {
    func encodeCOBS() -> Data {
        var r = Data(count: self.count + (self.count / 254) + 1) // Encoded frame will be 1 larger for each 254 bytes
        var codeIdx = 0
        var write = 1
        r[codeIdx] = 1
        for x in self {
            if x == 0x00 {
                codeIdx = write
                write += 1
                r[codeIdx] = 1
            }
            else {
                r[codeIdx] += 1
                r[write] = x
                write += 1
                if r[codeIdx] == 0xff {
                    codeIdx = write
                    write += 1
                    r[codeIdx] = 1
                }
            }
        }
        
        return r.subdata(in: 0..<write)
    }
    
    func decodeCOBS() -> Data? {
        var r = Data(count: self.count)  // Decoded frame will always be smaller
        var write = 0
        var code = UInt8(0)
        var zeroSeg = false
        for x in self {
            if code == 0 {
                if zeroSeg {
                    r[write] = 0x00
                    write += 1
                }
                guard x >= 1 else { return nil }
                zeroSeg = x < 255
                code = x - 1
            }
            else {
                r[write] = x
                write += 1
                code -= 1
            }
        }
        
        return r.subdata(in: 0..<write)
    }
}
