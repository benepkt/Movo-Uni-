// Onboarding Screens - Phase 2: Feature Showcases
// Screen 16: Track Progress (Revamped)

import SwiftUI

// MARK: - Screen 16: Track Progress (Dashboard)
struct TrackProgressScreen: View {
    @EnvironmentObject var appSettings: AppSettings
    @State private var showCards = false
    @AppStorage("onboarding.language") private var onboardingLanguage: String = Locale.current.language.languageCode?.identifier ?? "en"
    
    private func localizedOnboarding(_ key: String) -> String {
        let dict = onboardingLanguage == "de" ? LocalizedStrings.de : LocalizedStrings.en
        return dict[key] ?? key
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Text(onboardingLanguage == "de" ? "Verfolge deinen Fortschritt" : "Track your progress")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            
            // Dashboard Cards - Movo Style
            VStack(spacing: 16) {
                // Card 1: Movo Score (Circle)
                HStack {
                    VStack(alignment: .leading) {
                        Text(onboardingLanguage == "de" ? "Movo Score" : "Movo Score")
                            .font(.headline)
                        Text("87")
                            .font(.system(size: 48, weight: .black))
                            .foregroundStyle(Color(hex: 0x4C5BFF))
                        Text(onboardingLanguage == "de" ? "Stark" : "Strong")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                        Circle()
                            .trim(from: 0, to: 0.87)
                            .stroke(
                                LinearGradient(colors: [Color(hex: 0x4C5BFF), .purple], startPoint: .top, endPoint: .bottom),
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 80, height: 80)
                }
                .padding(20)
                .background(RoundedRectangle(cornerRadius: 24).fill(Color(hex: 0x111111)))
                .offset(x: showCards ? 0 : -50)
                .opacity(showCards ? 1 : 0)
                
                // Card 2: Level / XP (Statistics Style)
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(colors: [.white, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .frame(width: 56, height: 56)
                            .shadow(color: .white.opacity(0.3), radius: 8, x: 0, y: 4)
                        
                        Image(systemName: "crown.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(Color(hex: 0x111111))
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Level 24")
                            .font(.headline)
                        
                        Text(onboardingLanguage == "de" ? "Gold" : "Gold")
                            .font(.subheadline.bold())
                            .foregroundStyle(.yellow)
                        
                        // Mini Progress Bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.1))
                                Capsule().fill(Color.white).frame(width: geo.size.width * 0.95)
                            }
                        }
                        .frame(height: 6)
                        .padding(.top, 4)
                    }
                    Spacer()
                }
                .padding(20)
                .background(RoundedRectangle(cornerRadius: 24).fill(Color(hex: 0x111111)))
                .offset(x: showCards ? 0 : 50)
                .opacity(showCards ? 1 : 0)
                .animation(.spring().delay(0.1), value: showCards)
                
                // Card 3: Body Recovery (Cards Style)
                VStack(alignment: .leading, spacing: 12) {
                    Text(onboardingLanguage == "de" ? "Körper-Erholung" : "Body Recovery")
                        .font(.headline)
                    
                    HStack(spacing: 12) {
                        // Card A: Chest (Recovering)
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(onboardingLanguage == "de" ? "Brust" : "Chest")
                                    .font(.caption.bold())
                                Spacer()
                                Image(systemName: "battery.25")
                                    .foregroundStyle(.red)
                            }
                            
                            Capsule()
                                .fill(Color.red)
                                .frame(height: 4)
                                .overlay(alignment: .trailing) {
                                     // "12h" text maybe?
                                }
                            
                            Text(onboardingLanguage == "de" ? "Erholt sich" : "Recovering")
                                .font(.caption2.bold())
                                .foregroundStyle(.red)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(Color(hex: 0x1C1C1E))
                        .cornerRadius(12)
                        
                        // Card B: Legs (Ready)
                        VStack(alignment: .leading, spacing: 8) {
                             HStack {
                                 Text("Legs")
                                     .font(.caption.bold())
                                 Spacer()
                                 Image(systemName: "battery.100")
                                     .foregroundStyle(.green)
                             }
                             
                             Capsule()
                                 .fill(Color.green)
                                 .frame(height: 4)
                             
                             Text("Peak")
                                 .font(.caption2.bold())
                                 .foregroundStyle(.green)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(Color(hex: 0x1C1C1E))
                        .cornerRadius(12)
                    }
                }
                .padding(20)
                .background(RoundedRectangle(cornerRadius: 24).fill(Color(hex: 0x111111)))
                .offset(y: showCards ? 0 : 50)
                .opacity(showCards ? 1 : 0)
                .animation(.spring().delay(0.2), value: showCards)
            }
            .padding(.horizontal, 24)
            
            Text(onboardingLanguage == "de" ? "Visualisiere deine Fortschritte mit erweiterten Analysen." : "Visualize your gains with advanced analytics.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
                .padding(.horizontal, 32)
            
            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                showCards = true
            }
        }
    }
}

// MARK: - Screen 16b: Statistics Showcaes (New)
struct TrackStatisticsScreen: View {
    @EnvironmentObject var appSettings: AppSettings
    @State private var animate = false
    @AppStorage("onboarding.language") private var onboardingLanguage: String = Locale.current.language.languageCode?.identifier ?? "en"
    
    private func localizedOnboarding(_ key: String) -> String {
        let dict = onboardingLanguage == "de" ? LocalizedStrings.de : LocalizedStrings.en
        return dict[key] ?? key
    }
    
    // Mock Olympian Ranks for Visualization
    private let olympianRanks: [MuscleRegion: MuscleRank] = {
        var ranks: [MuscleRegion: MuscleRank] = [:]
        for region in MuscleRegion.allCases {
            ranks[region] = .olympian
        }
        return ranks
    }()
    
    private var regionColorsNow: [MuscleRegion: Color] {
        olympianRanks.mapValues { $0.color }
    }
    
    var body: some View {
        VStack(spacing: 24) {
             Spacer()
             
             Text(localizedOnboarding("onboarding.statistics.title"))
                 .font(.largeTitle.bold())
                 .multilineTextAlignment(.center)
                 .fixedSize(horizontal: false, vertical: true)
            
             Text(localizedOnboarding("onboarding.statistics.subtitle"))
                 .font(.body)
                 .multilineTextAlignment(.center)
                 .foregroundStyle(.secondary)
                 .fixedSize(horizontal: false, vertical: true)
                 .padding(.horizontal, 32)
            
             // 1:1 Replica of MuscleRankView (Statistics) with Olympian Data
             TabView {
                 // PAGE 1: Body Map (The one user liked)
                 VStack(alignment: .leading, spacing: 16) {
                     // Header
                     HStack {
                         VStack(alignment: .leading, spacing: 4) {
                             Text(appSettings.localized("statistics.level.yours") != "statistics.level.yours" ? appSettings.localized("statistics.level.yours") : "Your Level")
                                 .font(.subheadline)
                                 .foregroundStyle(.secondary)
                             Text("Olympian God") // Hardcoded Goal
                                 .font(.title2.bold())
                                 .foregroundStyle(Color(hex: 0x4C5BFF)) // Primary Color
                         }
                         Spacer()
                         
                         // Mock Legend Button (Visual)
                         Image(systemName: "info.circle")
                             .font(.title3)
                             .foregroundStyle(.secondary)
                     }
                     
                     // Body Map Content (Standard Single View)
                     VStack(spacing: 16) {
                         HStack(spacing: 16) {
                             // Front View
                             MuscleFigure(side: .front, regionColors: regionColorsNow)
                             // Back View
                             MuscleFigure(side: .back, regionColors: regionColorsNow)
                         }
                         .frame(maxWidth: .infinity)
                         .frame(height: 180)
                         
                         // Progress Chips (All Olympian)
                         ScrollView(.horizontal, showsIndicators: false) {
                             HStack(spacing: 12) {
                                 // Only show top ranks as showcase
                                 HStack(spacing: 6) {
                                     Circle().fill(MuscleRank.olympian.color).frame(width: 8, height: 8)
                                     Text("Olympian: \(MuscleRegion.allCases.count)")
                                         .font(.caption.bold())
                                         .foregroundStyle(.primary)
                                 }
                                 .padding(.horizontal, 10)
                                 .padding(.vertical, 6)
                                 .background(Color.secondary.opacity(0.1))
                                 .clipShape(Capsule())
                             }
                         }
                     }
                 }
                 .padding(20)
                 .background(Color(hex: 0x1C1C1E))
                 .cornerRadius(24)
                 .padding(.horizontal, 24)
                 
                 // PAGE 2: Activity Heatmap (Restored)
                 VStack(alignment: .leading, spacing: 16) {
                     Text(localizedOnboarding("onboarding.statistics.activityStreak"))
                         .font(.headline)
                         .foregroundStyle(.white)
                     
                     LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 20), spacing: 4) {
                         ForEach(0..<140) { index in
                             RoundedRectangle(cornerRadius: 2)
                                 .fill(Color(hex: 0x4C5BFF).opacity(Double.random(in: 0.1...1.0)))
                                 .frame(height: 10)
                         }
                     }
                     
                     // Text removed as per feedback
                 }
                 .padding(20)
                 .background(Color(hex: 0x1C1C1E))
                 .cornerRadius(24)
                 .padding(.horizontal, 24)
                 
             }
             .tabViewStyle(.page(indexDisplayMode: .always))
             .frame(height: 380) // Restrict height for paging
             
             Spacer()
        }
    }
}
