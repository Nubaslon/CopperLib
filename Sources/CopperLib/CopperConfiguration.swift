//
//  CopperConfiguration.swift
//  CopperLib
//
//  Created by ANTROPOV Evgeny on 16.02.2022.
//


#if !FROM_COCOAPODS
import CopperPlugin
import Peertalk
#else
import PeerTalk
#endif
#if !os(macOS)
@available(iOS 13.0, *)
public class CopperConfiguration  {
    public static let shared = CopperConfiguration()
    let clientManager = CopperClientManager()
    
    
    public func registerPlugin(plugin: Plugin) {
        clientManager.registerPlugin(plugin: plugin)
    }
}
#endif
