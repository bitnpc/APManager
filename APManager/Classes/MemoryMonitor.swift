//
//  MemoryMonitor.swift
//  APManager
//
//  Created by Tony Clark on 2019/12/12.
//

import Foundation

public class MemoryMonitor: NSObject {
    
    @objc public static let sharedInstance: MemoryMonitor = MemoryMonitor()
    
    var timer: DispatchSourceTimer?
    private var maxMemory: UInt64 = 0
    
    @objc public func start() -> Void {
        timer = DispatchSource.makeTimerSource(queue: .global())
        timer?.schedule(wallDeadline: .now(), repeating: .seconds(3))
        timer?.setEventHandler { [weak self] in
            guard let ss = self else { return }
            let usedMemory: UInt64 = MemoryMonitor.usedMemory()
            // 3 秒内分配超过 500M 内存，触发 assertion
            if (usedMemory > ss.maxMemory && usedMemory - ss.maxMemory > 500) {
                assertionFailure("Abnormal memory allocation.")
            }
            ss.maxMemory = max(ss.maxMemory, usedMemory)
        }
        timer?.resume()
    }
    
    @objc public func stop() -> Void {
        timer?.cancel()
        timer = nil
    }
    
    public static func usedMemory() -> UInt64 {
        let TASK_VM_INFO_COUNT = MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size
        var vmInfo: task_vm_info_data_t = task_vm_info_data_t()
        var vmInfoSize = mach_msg_type_number_t(TASK_VM_INFO_COUNT)
        
        let kern: kern_return_t = withUnsafeMutablePointer(to: &vmInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                          task_flavor_t(TASK_VM_INFO),
                          $0,
                          &vmInfoSize)
            }
        }
        if kern == KERN_SUCCESS {
            let usedSize = vmInfo.phys_footprint / 1024 / 1024
            return usedSize
        } else {
            return 0
        }
    }
    
    public static func totalMemory() -> UInt64 {
        let size: UInt64 = ProcessInfo.processInfo.physicalMemory / 1024 / 1024
        return size
    }
}
