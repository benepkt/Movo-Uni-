import SwiftUI
import Combine

// MARK: - Equipment Model
struct EquipmentItem: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let icon: String // SF Symbol name
    let type: EquipmentType
    
    enum EquipmentType: String, Codable {
        case freeWeights = "Freie Gewichte"
        case machines = "Maschinen"
        case cardio = "Cardio"
        case bodyweight = "Körpergewicht"
        case other = "Sonstiges"
    }
}

// MARK: - Equipment Store
@MainActor
final class EquipmentStore: ObservableObject {
    @Published var selectedEquipmentIDs: Set<String> = []
    
    private let defaults = UserDefaults.standard
    private let storageKey = "user_equipment_ids"
    
    // Hardcoded Database of Equipment
    let allEquipment: [EquipmentItem] = [
        // Free Weights
        .init(id: "barbell", name: "Langhantel", icon: "figure.strengthtraining.traditional", type: .freeWeights),
        .init(id: "dumbbells", name: "Kurzhanteln", icon: "dumbbell.fill", type: .freeWeights),
        .init(id: "kettlebell", name: "Kettlebell", icon: "scalemass.fill", type: .freeWeights),
        .init(id: "ez_bar", name: "SZ-Stange", icon: "figure.strengthtraining.traditional", type: .freeWeights),
        .init(id: "plates", name: "Gewichtsscheiben", icon: "circle.circle.fill", type: .freeWeights),
        .init(id: "trap_bar", name: "Trap-Bar", icon: "figure.strengthtraining.traditional", type: .freeWeights),
        
        // Machines
        .init(id: "cable_tower", name: "Kabelzugturm", icon: "lines.measurement.horizontal", type: .machines),
        .init(id: "leg_press", name: "Beinpresse", icon: "figure.seated.seatbelt", type: .machines),
        .init(id: "lat_pulldown", name: "Latzug", icon: "arrow.down.to.line", type: .machines),
        .init(id: "smith_machine", name: "Multipresse", icon: "door.garage.closed", type: .machines),
        .init(id: "leg_extension", name: "Beinstrecker", icon: "figure.seated.side.right", type: .machines),
        .init(id: "leg_curl", name: "Beinbeuger", icon: "figure.seated.side.left", type: .machines),
        
        // Cardio
        .init(id: "treadmill", name: "Laufband", icon: "figure.run", type: .cardio),
        .init(id: "elliptical", name: "Crosstrainer", icon: "figure.elliptical", type: .cardio),
        .init(id: "stationary_bike", name: "Fahrrad", icon: "bicycle", type: .cardio),
        .init(id: "rowing_machine", name: "Rudergerät", icon: "figure.rower", type: .cardio),
        
        // Bodyweight / Calisthenics
        .init(id: "pullup_bar", name: "Klimmzugstange", icon: "figure.highintensity.intervaltraining", type: .bodyweight),
        .init(id: "dip_bars", name: "Dip-Barren", icon: "parallel.bars", type: .bodyweight),
        .init(id: "rings", name: "Turnringe", icon: "circle.grid.cross", type: .bodyweight),
        
        // Other
        .init(id: "bench", name: "Hantelbank", icon: "table.furniture", type: .other),
        .init(id: "bands", name: "Widerstandsbänder", icon: "lineweight", type: .other)
    ]
    
    init() {
        loadWithMigration()
    }
    
    // MARK: - Actions
    
    func toggle(_ item: EquipmentItem) {
        if selectedEquipmentIDs.contains(item.id) {
            selectedEquipmentIDs.remove(item.id)
        } else {
            selectedEquipmentIDs.insert(item.id)
        }
        save()
    }
    
    func selectAll() {
        selectedEquipmentIDs = Set(allEquipment.map { $0.id })
        save()
    }
    
    func deselectAll() {
        selectedEquipmentIDs.removeAll()
        save()
    }
    
    func has(_ id: String) -> Bool {
        selectedEquipmentIDs.contains(id)
    }
    
    // MARK: - Persistence
    
    private func save() {
        if let data = try? JSONEncoder().encode(selectedEquipmentIDs) {
            defaults.set(data, forKey: storageKey)
        }
    }
    
    private func loadWithMigration() {
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) {
            self.selectedEquipmentIDs = decoded
        } else {
            // Default: Assume minimal gym setup if nothing saved
            // Or maybe empty? Let's start with empty so they choose.
            self.selectedEquipmentIDs = []
        }
    }
}
