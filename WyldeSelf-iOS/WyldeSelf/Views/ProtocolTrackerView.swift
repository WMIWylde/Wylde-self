import SwiftUI

struct ProtocolTrackerView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var service = ProtocolTrackerService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showSideEffectSheet = false
    @State private var sideEffectPrescriptionId: String?
    @State private var sideEffectNote = ""

    var body: some View {
        ZStack {
            Theme.appBG.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("PROTOCOL TRACKER")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(2.5)
                                .foregroundColor(Color(hex: "C8A96E"))
                            Text("Your active protocol")
                                .font(.system(size: 22, weight: .bold, design: .serif))
                                .foregroundColor(Theme.primaryText)
                        }
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Theme.secondaryText)
                                .frame(width: 36, height: 36)
                                .background(Theme.elevatedBG)
                                .clipShape(Circle())
                        }
                    }

                    // Adherence rate
                    if let rate = service.adherenceRate {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .stroke(Color.white.opacity(0.06), lineWidth: 5)
                                    .frame(width: 56, height: 56)
                                Circle()
                                    .trim(from: 0, to: CGFloat(rate) / 100)
                                    .stroke(adherenceColor(rate), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                                    .frame(width: 56, height: 56)
                                    .rotationEffect(.degrees(-90))
                                Text("\(rate)%")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(Theme.primaryText)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Protocol Adherence")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Theme.primaryText)
                                Text("Last 14 days")
                                    .font(.system(size: 11))
                                    .foregroundColor(Theme.secondaryText)
                            }
                        }
                        .padding(16)
                        .background(Theme.elevatedBG)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    // Active prescriptions
                    if service.prescriptions.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "pills")
                                .font(.system(size: 32))
                                .foregroundColor(Theme.tertiaryText)
                            Text("No active prescriptions")
                                .font(.system(size: 14))
                                .foregroundColor(Theme.secondaryText)
                            Text("Your clinician will assign protocols from their dashboard.")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.tertiaryText)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        Text("Today's Protocol")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.secondaryText)

                        ForEach(service.prescriptions, id: \.id) { rx in
                            prescriptionCard(rx)
                        }
                    }

                    // Recent adherence log
                    if !service.adherenceLogs.isEmpty {
                        Text("Recent Log")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.secondaryText)
                            .padding(.top, 8)

                        ForEach(service.adherenceLogs.prefix(10)) { log in
                            HStack(spacing: 10) {
                                Image(systemName: log.status == "taken" ? "checkmark.circle.fill" : "xmark.circle")
                                    .foregroundColor(log.status == "taken" ? Color(hex: "7A8771") : Color(hex: "C26B5A"))
                                    .font(.system(size: 16))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(log.dose ?? "Dose logged")
                                        .font(.system(size: 13))
                                        .foregroundColor(Theme.primaryText)
                                    if let date = log.createdAt {
                                        Text(date.prefix(10))
                                            .font(.system(size: 10))
                                            .foregroundColor(Theme.tertiaryText)
                                    }
                                }
                                Spacer()
                                Text(log.status.capitalized)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(log.status == "taken" ? Color(hex: "7A8771") : Color(hex: "C26B5A"))
                            }
                            .padding(12)
                            .background(Theme.elevatedBG)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    // Disclaimer
                    Text("Protocol changes must be made by your clinician. Contact your care team if you have concerns.")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.tertiaryText)
                        .padding(.top, 12)

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
        }
        .task { await service.fetch() }
        .sheet(isPresented: $showSideEffectSheet) {
            sideEffectSheet
        }
    }

    // MARK: - Prescription Card

    private func prescriptionCard(_ rx: MeResponse.Prescription) -> some View {
        let todayLogged = service.adherenceLogs.contains { $0.prescriptionId?.uuidString == rx.id && $0.status == "taken" }

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(rx.drug)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Theme.primaryText)
                    Text("\(rx.dose) · \(rx.frequency)")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.secondaryText)
                }
                Spacer()
                if todayLogged {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(hex: "7A8771"))
                        .font(.system(size: 24))
                }
            }

            if !todayLogged {
                HStack(spacing: 8) {
                    Button {
                        Task { await service.logDose(prescriptionId: rx.id, protocolId: nil, status: "taken", dose: rx.dose) }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                            Text("Taken")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(Theme.onAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color(hex: "7A8771"))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    Button {
                        Task { await service.logDose(prescriptionId: rx.id, protocolId: nil, status: "skipped") }
                    } label: {
                        Text("Skip")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Theme.secondaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(Theme.chipBG)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    Button {
                        sideEffectPrescriptionId = rx.id
                        showSideEffectSheet = true
                    } label: {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "C26B5A"))
                            .frame(width: 42, height: 38)
                            .background(Color(hex: "C26B5A").opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
        .padding(16)
        .background(Theme.elevatedBG)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(todayLogged ? Color(hex: "7A8771").opacity(0.2) : Theme.primaryText.opacity(0.06), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Side Effect Sheet

    private var sideEffectSheet: some View {
        NavigationStack {
            ZStack {
                Theme.appBG.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 16) {
                    Text("Report a side effect")
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundColor(Theme.primaryText)

                    Text("This will be shared with your clinician.")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.secondaryText)

                    TextField("Describe what you're experiencing...", text: $sideEffectNote, axis: .vertical)
                        .lineLimit(3...6)
                        .font(.system(size: 14))
                        .foregroundColor(Theme.primaryText)
                        .padding(14)
                        .background(Theme.elevatedBG)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .tint(Color(hex: "C8A96E"))

                    GoldButton(label: "Submit Report") {
                        if let rxId = sideEffectPrescriptionId {
                            Task {
                                await service.logDose(
                                    prescriptionId: rxId,
                                    protocolId: nil,
                                    status: "taken",
                                    notes: sideEffectNote,
                                    sideEffects: ["report": sideEffectNote]
                                )
                                showSideEffectSheet = false
                                sideEffectNote = ""
                            }
                        }
                    }

                    Spacer()
                }
                .padding(20)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { showSideEffectSheet = false }
                        .foregroundColor(Theme.secondaryText)
                }
            }
        }
    }

    private func adherenceColor(_ rate: Int) -> Color {
        if rate >= 80 { return Color(hex: "7A8771") }
        if rate >= 50 { return Color(hex: "C8A96E") }
        return Color(hex: "C26B5A")
    }
}
