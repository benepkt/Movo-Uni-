import Foundation
import SwiftUI
import RevenueCat
import Combine

@MainActor
class PurchaseManager: NSObject, ObservableObject {
    static let shared = PurchaseManager()

    @Published var isPremium = false
    @Published var customerInfo: CustomerInfo?
    @Published var offerings: Offerings?

    override init() {
        super.init()
        // ⚠️ TODO: Replace with your actual RevenueCat API Key
        Purchases.configure(withAPIKey: "appl_ZRxdqNluQaSEPiYnceKaOvLezJr")
        
        Purchases.shared.delegate = self
        
        // Initial fetch
        refreshCustomerInfo()
        fetchOfferings()
    }

    func refreshCustomerInfo() {
        Purchases.shared.getCustomerInfo { [weak self] info, error in
            if let info = info {
                self?.updateStatus(with: info, source: "AppLaunch/Refresh")
            }
        }
    }
    
    func fetchOfferings() {
        Purchases.shared.getOfferings { [weak self] offerings, error in
            if let offerings = offerings {
                self?.offerings = offerings
            }
        }
    }
    
    func logIn(appUserID: String) {
        Task {
            do {
                // 1. Identify User
                let (info, created) = try await Purchases.shared.logIn(appUserID)
                
                // 2. Force Sync with Apple Receipt to ensure we match the current Apple ID
                // This prevents 'inheriting' a receipt from a previous user on the same device in some cases
                _ = try? await Purchases.shared.syncPurchases()
                
                // 3. Update Status
                self.updateStatus(with: info, source: "Login+Sync (created: \(created))")
                print("[PurchaseManager] Logged in as \(appUserID). Synced with Apple.")
            } catch {
                print("[PurchaseManager] Login failed: \(error)")
            }
        }
    }
    
    func logout() {
        Task {
            // Log out from RevenueCat (generates new anonymous ID)
            do {
                let info = try await Purchases.shared.logOut()
                self.updateStatus(with: info, source: "Logout") // Will likely remain premium if anon ID inherits receipt
                
                // Optional: Clear cache text or similar if needed
                print("[PurchaseManager] Logged out. New Anon ID generated.")
            } catch {
                print("[PurchaseManager] Logout failed: \(error)")
            }
        }
    }
    
    func syncReceipt() {
        Task {
            do {
                print("[PurchaseManager] Starting manual sync...")
                let info = try await Purchases.shared.syncPurchases()
                self.updateStatus(with: info, source: "ManualSync/Button")
                print("[PurchaseManager] Manual sync done. Active: \(info.entitlements.active.keys)")
            } catch {
                print("[PurchaseManager] Manual sync failed: \(error)")
            }
        }
    }

    // Debugging Source
    @Published var debugSource: String = "Init"

    func updateStatus(with info: CustomerInfo, source: String) {
        self.customerInfo = info
        // Check for ANY active entitlement to be safe
        self.isPremium = !info.entitlements.active.isEmpty
        self.debugSource = source
        print("[PurchaseManager] updateStatus (Source: \(source)) -> isPremium: \(self.isPremium)")
    }
}

extension PurchaseManager: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            updateStatus(with: customerInfo, source: "Delegate/AutoSync")
        }
    }
}
