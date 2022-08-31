//
//  UUID.swift
//  
//
//  Created by ANTROPOV Evgeny on 16.02.2022.
//

import Foundation

public extension Foundation.UUID {
    var data: Data {
        return withUnsafeBytes(of: self.uuid, { Data($0) })
    }
}

public extension Data {
    var uuid: UUID {
        let bytes:uuid_t = (self[0], self[1], self[2], self[3], self[4], self[5], self[6], self[7], self[8], self[9], self[10], self[11], self[12], self[13], self[14], self[15])        
        return UUID(uuid:bytes)
    }
}
