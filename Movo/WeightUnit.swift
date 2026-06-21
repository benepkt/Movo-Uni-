import Foundation
import SwiftUI

// MARK: - WeightUnit Enum
enum WeightUnit: String, CaseIterable {
    case kg, lb
    
    var symbol: String {
        switch self {
        case .kg: return "kg"
        case .lb: return "lb"
        }
    }
    
    func fromKilograms(_ kg: Double) -> Double {
        switch self {
        case .kg: return kg
        case .lb: return kg * 2.20462
        }
    }
    
    func toKilograms(_ value: Double) -> Double {
        switch self {
        case .kg: return value
        case .lb: return value / 2.20462
        }
    }
    
    func format(kg: Double, decimals: Int) -> String {
        let value = fromKilograms(kg)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = decimals
        let formatted = formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
        return "\(formatted) \(symbol)"
    }
}
