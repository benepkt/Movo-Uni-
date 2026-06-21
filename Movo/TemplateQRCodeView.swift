import SwiftUI

struct TemplateQRCodeView: View {
    let template: TrainingTemplate
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appSettings: AppSettings
    
    @State private var qrCodeImage: UIImage?
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Image(systemName: "qrcode")
                                .font(.system(size: 50))
                                .foregroundStyle(.blue)
                            
                            Text(template.name)
                                .font(.title2.bold())
                                .multilineTextAlignment(.center)
                            
                            Text("\(template.exercises.count) \(template.exercises.count == 1 ? appSettings.localized("exercise") : appSettings.localized("exercises"))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 20)
                        
                        // QR Code Card
                        VStack(spacing: 16) {
                            if let qrImage = qrCodeImage {
                                Image(uiImage: qrImage)
                                    .interpolation(.none)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 280, height: 280)
                                    .padding(20)
                                    .background(Color.white)
                                    .cornerRadius(16)
                                    .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                            } else {
                                ProgressView()
                                    .frame(width: 280, height: 280)
                            }
                            
                            Text(appSettings.localized("template.qr.scan"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(20)
                        .padding(.horizontal)
                        
                        // Instructions
                        VStack(alignment: .leading, spacing: 12) {
                            InstructionRow(
                                icon: "camera.fill",
                                text: appSettings.localized("template.qr.step1")
                            )
                            
                            InstructionRow(
                                icon: "viewfinder",
                                text: appSettings.localized("template.qr.step2")
                            )
                            
                            InstructionRow(
                                icon: "arrow.down.circle.fill",
                                text: appSettings.localized("template.qr.step3")
                            )
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .onAppear {
            generateQRCode()
        }
    }
    
    private func generateQRCode() {
        qrCodeImage = TemplateSharingService.generateQRCode(from: template)
    }
    
    private func shareQRCode() {
        guard let qrImage = qrCodeImage else { return }
        
        let exerciseCount = template.exercises.count
        let exerciseWord = exerciseCount == 1 ? appSettings.localized("exercise") : appSettings.localized("exercises")
        let shareText = """
        🏋️ \(appSettings.localized("template.qr.sharetext")): \(template.name)
        
        \(exerciseCount) \(exerciseWord)
        
        \(appSettings.localized("template.qr.scaninstruction"))
        """
        
        let activityVC = UIActivityViewController(
            activityItems: [shareText, qrImage],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = window
                popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            rootVC.present(activityVC, animated: true)
        }
    }
}

struct InstructionRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 30)
            
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
            
            Spacer()
        }
    }
}

#Preview {
    TemplateQRCodeView(template: TrainingTemplate(
        id: "1",
        name: "Push Training",
        exercises: ["Bench Press", "Incline Press", "Shoulder Press"],
        ownerId: "user1",
        updatedAt: Date()
    ))
    .environmentObject(AppSettings())
}
