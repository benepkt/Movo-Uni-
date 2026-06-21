import SwiftUI
import UIKit

public enum MuscleSide { case front, back }

public final class AssetNameResolver {
    public static let shared = AssetNameResolver()
    private var cache: [String: Bool] = [:]

    public func exists(_ name: String) -> Bool {
        if let v = cache[name] { return v }
        let ok = UIImage(named: name) != nil
        cache[name] = ok
        return ok
    }

    public func resolve(_ candidates: [String]) -> String? {
        candidates.first(where: exists)
    }
}

public enum MuscleRegion: String, CaseIterable, Hashable, Codable {
    // Front
    case chest, shoulders, biceps, forearms, abs, quads, calves
    // Back
    case traps, lats, triceps, lowerBack, glutes, hamstrings, calvesBack

    public var side: MuscleSide {
        switch self {
        case .chest, .shoulders, .biceps, .forearms, .abs, .quads, .calves: return .front
        case .traps, .lats, .triceps, .lowerBack, .glutes, .hamstrings, .calvesBack: return .back
        }
    }

    /// Kandidaten: erst "saubere" Namen, dann ".png", dann aktuelle Asset-Namen
    public var candidateAssetNames: [String] {
        switch self {
        case .chest:      return ["muscle_front_chest", "muscle_front_chest.png"]
        case .shoulders:  return ["muscle_front_shoulders", "muscle_front_shoulders.png"]
        case .biceps:     return ["muscle_front_biceps", "muscle_front_biceps.png", "upperarms_front"]
        case .forearms:   return ["muscle_front_forearms", "muscle_front_forearms.png", "forearms_front"]
        case .abs:        return ["muscle_front_abs", "muscle_front_abs.png"]
        case .quads:      return ["muscle_front_quads", "muscle_front_quads.png"]
        case .calves:     return ["muscle_front_calves", "muscle_front_calves.png"]

        case .traps:      return ["muscle_back_traps", "muscle_back_traps.png", "traps_back"]
        case .lats:       return ["muscle_back_lats", "muscle_back_lats.png"]
        case .triceps:    return ["muscle_back_triceps", "muscle_back_triceps.png", "triceps_back"]
        case .lowerBack:  return ["muscle_back_lowerback", "muscle_back_lowerBack", "midback_back"]
        case .glutes:     return ["muscle_back_glutes", "muscle_back_glutes.png"]
        case .hamstrings: return ["muscle_back_hamstrings", "muscle_back_hamstrings.png", "hamstrings_back"]
        case .calvesBack: return ["muscle_back_calves", "muscle_back_calves.png"]
        }
    }

    public var resolvedAssetName: String? {
        AssetNameResolver.shared.resolve(candidateAssetNames)
    }
}

/// Helper functions for mapping exercises to muscles
public struct MuscleMappingHelper {
    public static func regions(forExerciseName n: String) -> [MuscleRegion] {
        let name = n.lowercased()
        if name.contains("bench") || name.contains("bank") || name.contains("chest") { return [.chest, .triceps, .shoulders] }
        if name.contains("overhead") || name.contains("military") || name.contains("shoulder") { return [.shoulders, .triceps] }
        if name.contains("curl") || name.contains("bizeps") || name.contains("biceps") { return [.biceps, .forearms] }
        if name.contains("triceps") || name.contains("pushdown") || name.contains("dip") { return [.triceps] }
        if name.contains("pullup") || name.contains("chin") || name.contains("lat") { return [.lats, .biceps] }
        if name.contains("row") || name.contains("rudern") { return [.lats, .traps, .biceps] }
        if name.contains("deadlift") || name.contains("kreuzheben") { return [.lowerBack, .glutes, .hamstrings] }
        if name.contains("squat") || name.contains("kniebeuge") { return [.quads, .glutes, .hamstrings] }
        if name.contains("leg extension") || name.contains("beinstrecker") { return [.quads] }
        if name.contains("leg curl") || name.contains("beinbeuger") { return [.hamstrings] }
        if name.contains("calf") || name.contains("waden") { return [.calves, .calvesBack] }
        if name.contains("abs") || name.contains("bauch") || name.contains("crunch") || name.contains("plank") { return [.abs] }
        return []
    }
}
