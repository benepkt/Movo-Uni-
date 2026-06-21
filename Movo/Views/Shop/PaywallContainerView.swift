import SwiftUI
import RevenueCat
import RevenueCatUI

struct PaywallContainerView: View {
    var offering: Offering? // 🟢 Optional explicit offering
    var onPurchaseCompleted: (CustomerInfo) -> Void
    var onRestoreCompleted: (CustomerInfo) -> Void
    var onDismiss: () -> Void

    var body: some View {
        Group {
            if let offering = offering {
                PaywallView(offering: offering)
                    .onPurchaseCompleted { info in
                        onPurchaseCompleted(info)
                        onDismiss() // Auto-dismiss on success
                    }
                    .onRestoreCompleted { info in
                        onRestoreCompleted(info)
                        if info.entitlements["pro"]?.isActive == true {
                            onDismiss()
                        }
                    }
            } else {
                VStack(spacing: 20) {
                    ProgressView()
                    Text("Lade Angebote...")
                        .foregroundStyle(.secondary)
                    Text("(Falls dies lange dauert: Prüfe, ob in RevenueCat ein 'Current Offering' gesetzt ist)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            }
        }
        .onAppear {
            print("PaywallContainerView appeared. Offering available: \(offering != nil)")
        }
    }
}
