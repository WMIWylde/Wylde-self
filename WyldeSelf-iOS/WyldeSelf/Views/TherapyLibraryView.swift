import SwiftUI

struct TherapyLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var therapies: [TherapyItem] = []
    @State private var selectedType: String? = nil
    @State private var searchText = ""
    @State private var isLoading = true
    @State private var selectedTherapy: TherapyDetail?

    private let types = ["peptide", "hormone", "medication", "supplement"]
    private let categories = ["recovery", "metabolic", "longevity", "hormone_optimization", "inflammation", "hair", "immune", "cognitive", "sleep", "sexual_health"]

    var body: some View {
        ZStack {
            Color(hex: "070707").ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("WYLDE LIBRARY")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(2.5)
                            .foregroundColor(Color(hex: "C8A96E"))
                        Text("Research Library")
                            .font(.system(size: 22, weight: .bold, design: .serif))
                            .foregroundColor(Color(hex: "F4F1E8"))
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: "A6A29A"))
                            .frame(width: 36, height: 36)
                            .background(Color(hex: "111111"))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                // Search
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Color(hex: "6E6B65"))
                    TextField("Search therapies...", text: $searchText)
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "F4F1E8"))
                        .tint(Color(hex: "C8A96E"))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(hex: "111111"))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .onChange(of: searchText) { _ in Task { await loadTherapies() } }

                // Type filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        filterChip("All", isSelected: selectedType == nil) { selectedType = nil; Task { await loadTherapies() } }
                        ForEach(types, id: \.self) { type in
                            filterChip(type.capitalized + "s", isSelected: selectedType == type) { selectedType = type; Task { await loadTherapies() } }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.top, 10)

                // Content
                if isLoading {
                    Spacer()
                    ProgressView().tint(Color(hex: "C8A96E"))
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 10) {
                            ForEach(therapies) { therapy in
                                therapyCard(therapy)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .task { await loadTherapies() }
        .sheet(item: $selectedTherapy) { detail in
            TherapyDetailView(therapy: detail)
        }
    }

    private func filterChip(_ label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isSelected ? Color(hex: "070707") : Color(hex: "A6A29A"))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? Color(hex: "C8A96E") : Color(hex: "1A1A1A"))
                .clipShape(Capsule())
        }
    }

    private func therapyCard(_ t: TherapyItem) -> some View {
        Button { Task { await loadDetail(t.slug) } } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(t.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color(hex: "F4F1E8"))
                        evidenceBadge(t.evidenceRating)
                    }
                    Text(t.shortDescription ?? "")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "A6A29A"))
                        .lineLimit(2)
                    HStack(spacing: 6) {
                        typeBadge(t.therapyType)
                        if t.requiresProviderReview == true {
                            Text("Provider review")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(Color(hex: "FF9A3C"))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(hex: "FF9A3C").opacity(0.10))
                                .clipShape(Capsule())
                        }
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "6E6B65"))
            }
            .padding(16)
            .background(Color(hex: "111111"))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color(hex: "F4F1E8").opacity(0.06), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func evidenceBadge(_ rating: String?) -> some View {
        let colors: [String: Color] = ["A": Color(hex: "7A8771"), "B": Color(hex: "5EE6D6"), "C": Color(hex: "C8A96E"), "D": Color(hex: "FF9A3C"), "X": Color(hex: "C26B5A")]
        let color = colors[rating ?? "X"] ?? Color(hex: "6E6B65")
        return Text(rating ?? "—")
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(color)
            .frame(width: 18, height: 18)
            .background(color.opacity(0.12))
            .clipShape(Circle())
    }

    private func typeBadge(_ type: String) -> some View {
        Text(type.capitalized)
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(Color(hex: "A6A29A"))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(hex: "1A1A1A"))
            .clipShape(Capsule())
    }

    // MARK: - Data

    private func loadTherapies() async {
        var urlStr = "https://www.wyldeself.com/api/library/therapies?"
        if let type = selectedType { urlStr += "type=\(type)&" }
        if !searchText.isEmpty { urlStr += "search=\(searchText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? searchText)&" }

        guard let url = URL(string: urlStr) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            struct Resp: Codable { let therapies: [TherapyItem] }
            let resp = try JSONDecoder().decode(Resp.self, from: data)
            therapies = resp.therapies
        } catch {
            print("[Library] Load failed: \(error.localizedDescription)")
        }
        isLoading = false
    }

    private func loadDetail(_ slug: String) async {
        guard let url = URL(string: "https://www.wyldeself.com/api/library/therapies?slug=\(slug)") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            struct Resp: Codable { let therapy: TherapyDetail }
            let resp = try JSONDecoder().decode(Resp.self, from: data)
            selectedTherapy = resp.therapy
        } catch {
            print("[Library] Detail load failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Models

struct TherapyItem: Identifiable, Codable {
    let id: UUID
    let slug: String
    let name: String
    let therapyType: String
    let category: String?
    let shortDescription: String?
    let evidenceRating: String?
    let prescriptionRequired: Bool?
    let requiresProviderReview: Bool?

    enum CodingKeys: String, CodingKey {
        case id, slug, name, category
        case therapyType = "therapy_type"
        case shortDescription = "short_description"
        case evidenceRating = "evidence_rating"
        case prescriptionRequired = "prescription_required"
        case requiresProviderReview = "requires_provider_review"
    }
}

struct TherapyDetail: Identifiable, Codable {
    let id: UUID
    let slug: String
    let name: String
    let therapyType: String
    let category: String?
    let shortDescription: String?
    let consumerSummary: String?
    let mechanismPlainEnglish: String?
    let commonUses: [String]?
    let potentialBenefits: [String]?
    let potentialRisks: [String]?
    let commonSideEffects: [String]?
    let contraindications: [String]?
    let administrationRoutes: [String]?
    let typicalDuration: String?
    let typicalDosingEducational: String?
    let fdaStatus: String?
    let evidenceRating: String?
    let evidenceSummary: String?
    let safetyDisclaimer: String?
    let prescriptionRequired: Bool?

    enum CodingKeys: String, CodingKey {
        case id, slug, name, category, contraindications
        case therapyType = "therapy_type"
        case shortDescription = "short_description"
        case consumerSummary = "consumer_summary"
        case mechanismPlainEnglish = "mechanism_plain_english"
        case commonUses = "common_uses"
        case potentialBenefits = "potential_benefits"
        case potentialRisks = "potential_risks"
        case commonSideEffects = "common_side_effects"
        case administrationRoutes = "administration_routes"
        case typicalDuration = "typical_duration"
        case typicalDosingEducational = "typical_dosing_educational"
        case fdaStatus = "fda_status"
        case evidenceRating = "evidence_rating"
        case evidenceSummary = "evidence_summary"
        case safetyDisclaimer = "safety_disclaimer"
        case prescriptionRequired = "prescription_required"
    }
}

// MARK: - Therapy Detail View

struct TherapyDetailView: View {
    let therapy: TherapyDetail
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(hex: "070707").ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    HStack {
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hex: "A6A29A"))
                                .frame(width: 36, height: 36)
                                .background(Color(hex: "111111"))
                                .clipShape(Circle())
                        }
                    }

                    Text(therapy.name)
                        .font(.system(size: 28, weight: .bold, design: .serif))
                        .foregroundColor(Color(hex: "F4F1E8"))

                    if let desc = therapy.shortDescription {
                        Text(desc)
                            .font(.system(size: 15))
                            .foregroundColor(Color(hex: "A6A29A"))
                            .lineSpacing(3)
                    }

                    // Badges
                    HStack(spacing: 8) {
                        badge(therapy.therapyType.capitalized, color: Color(hex: "C8A96E"))
                        if let cat = therapy.category { badge(cat.replacingOccurrences(of: "_", with: " ").capitalized, color: Color(hex: "7FD0FF")) }
                        if let fda = therapy.fdaStatus { badge(fda, color: Color(hex: "A6A29A")) }
                    }

                    // Sections
                    if let mechanism = therapy.mechanismPlainEnglish {
                        section("How It Works", content: mechanism)
                    }

                    if let uses = therapy.commonUses, !uses.isEmpty {
                        listSection("What It May Help With", items: uses)
                    }

                    if let benefits = therapy.potentialBenefits, !benefits.isEmpty {
                        listSection("Potential Benefits", items: benefits)
                    }

                    if let risks = therapy.potentialRisks, !risks.isEmpty {
                        listSection("Potential Risks", items: risks, color: Color(hex: "C26B5A"))
                    }

                    if let contra = therapy.contraindications, !contra.isEmpty {
                        listSection("Contraindications", items: contra, color: Color(hex: "C26B5A"))
                    }

                    if let routes = therapy.administrationRoutes, !routes.isEmpty {
                        section("Administration", content: routes.joined(separator: " · "))
                    }

                    // Evidence
                    if let rating = therapy.evidenceRating {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("EVIDENCE LEVEL")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(2)
                                .foregroundColor(Color(hex: "6E6B65"))
                            Text(evidenceLabel(rating))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hex: "F4F1E8"))
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(hex: "111111"))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    // Safety disclaimer
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(Color(hex: "FF9A3C"))
                                .font(.system(size: 12))
                            Text("IMPORTANT")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(2)
                                .foregroundColor(Color(hex: "FF9A3C"))
                        }
                        Text(therapy.safetyDisclaimer ?? "This information is for education only and is not medical advice.")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "A6A29A"))
                            .lineSpacing(3)
                    }
                    .padding(16)
                    .background(Color(hex: "FF9A3C").opacity(0.06))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "FF9A3C").opacity(0.15), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    // CTA
                    HStack(spacing: 8) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 14))
                        Text("Discuss with your provider")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(Color(hex: "1A1816"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(hex: "7A8771"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func section(_ title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(2)
                .foregroundColor(Color(hex: "6E6B65"))
            Text(content)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "F4F1E8"))
                .lineSpacing(3)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "111111"))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func listSection(_ title: String, items: [String], color: Color = Color(hex: "7A8771")) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(2)
                .foregroundColor(Color(hex: "6E6B65"))
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Circle().fill(color).frame(width: 5, height: 5).padding(.top, 6)
                    Text(item)
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "F4F1E8"))
                        .lineSpacing(2)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "111111"))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.10))
            .clipShape(Capsule())
    }

    private func evidenceLabel(_ rating: String) -> String {
        switch rating {
        case "A": return "A — Strong human clinical evidence"
        case "B": return "B — Moderate human evidence"
        case "C": return "C — Limited human evidence"
        case "D": return "D — Preclinical / animal / theoretical"
        case "X": return "X — Not enough reliable evidence"
        default: return "Not rated"
        }
    }
}
