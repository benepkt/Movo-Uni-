//  ExerciseCard.swift
//  Movo
//  Created by Benedikt on 27.09.25.

import SwiftUI

struct ExerciseCard: View {
    @EnvironmentObject var appSettings: AppSettings
    let title: String
    let timeRemaining: Int
    let nextTitle: String?
    let roundInfo: (current: Int, total: Int)   // aus der Session-Variante übernommen
    let setCount: Int
    let completedCount: Int
    let showSetDots: Bool                       // Flag, damit Dots bei Circuit verschwinden
    var onSkip: () -> Void

    // Expliziter Initializer mit Default für showSetDots
    init(
        title: String,
        timeRemaining: Int,
        nextTitle: String?,
        roundInfo: (current: Int, total: Int),
        setCount: Int,
        completedCount: Int,
        showSetDots: Bool = true,
        onSkip: @escaping () -> Void
    ) {
        self.title = title
        self.timeRemaining = timeRemaining
        self.nextTitle = nextTitle
        self.roundInfo = roundInfo
        self.setCount = setCount
        self.completedCount = completedCount
        self.showSetDots = showSetDots
        self.onSkip = onSkip
    }

    @State private var pulse = false

    var body: some View {
        VStack(spacing: 16) {
            // Titel + Runde
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.title2.bold())
                Text(String(format: appSettings.localized("round.of"), roundInfo.current, roundInfo.total))
                    .font(.footnote).foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Timer-Kreis
            ZStack {
                Circle().strokeBorder(Color.gray.opacity(0.2), lineWidth: 16).frame(width: 180, height: 180)
                Circle().fill(Color.accentColor.opacity(0.15))
                    .frame(width: pulse ? 210 : 190, height: pulse ? 210 : 190)
                    .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: pulse)
                Text("\(timeRemaining)")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity)
            .onAppear { pulse = true }

            // Runden-Dots
            HStack(spacing: 8) {
                ForEach(0..<roundInfo.total, id: \.self) { i in
                    Circle()
                        .fill(i < roundInfo.current ? Color.accentColor : Color.gray.opacity(0.25))
                        .frame(width: 10, height: 10)
                }
            }

            // Sets-Dots – nur wenn showSetDots == true (Strength)
            if showSetDots, setCount > 0 {
                HStack(spacing: 8) {
                    ForEach(0..<setCount, id: \.self) { i in
                        Circle()
                            .fill(i < completedCount ? Color.accentColor : Color.gray.opacity(0.25))
                            .frame(width: 14, height: 14)
                    }
                }
            }

            // Next + Skip
            if let next = nextTitle {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.right.circle.fill")
                    Text(next)
                    Spacer()
                    Button(role: .destructive, action: onSkip) {
                        Text(appSettings.localized("exercise.skip"))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white, lineWidth: 1)
                .opacity(0.06)
        )
    }
}
