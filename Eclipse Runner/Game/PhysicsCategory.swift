import Foundation

enum PhysicsCategory {
    static let none: UInt32      = 0
    static let player: UInt32    = 0x1 << 0
    static let obstacle: UInt32  = 0x1 << 1
    static let world: UInt32     = 0x1 << 2
    static let scoreGate: UInt32 = 0x1 << 3
}
