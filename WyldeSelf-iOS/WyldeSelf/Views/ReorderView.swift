import SwiftUI

struct ReorderView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var products: [ClinicProduct] = []
    @State private var orders: [ReorderRequest] = []
    @State private var isLoading = true
    @State private var selectedProduct: ClinicProduct?
    @State private var orderNote = ""
    @State private var showConfirm = false
    @State private var checkoutURL: URL?

    private let baseURL = "https://www.wyldeself.com"

    var body: some View {
        ZStack {
            Color(hex: "070707").ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("REFILL & REORDER")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(2.5)
                                .foregroundColor(Color(hex: "C8A96E"))
                            Text("Your clinic's products")
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

                    if isLoading {
                        HStack { Spacer(); ProgressView().tint(Color(hex: "C8A96E")); Spacer() }
                            .padding(.top, 40)
                    } else {
                        // Available products
                        if !products.isEmpty {
                            Text("Available")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color(hex: "A6A29A"))

                            ForEach(products) { product in
                                productCard(product)
                            }
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "shippingbox")
                                    .font(.system(size: 32))
                                    .foregroundColor(Color(hex: "6E6B65"))
                                Text("No products available")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(hex: "A6A29A"))
                                Text("Your clinician hasn't added products yet.")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "6E6B65"))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        }

                        // Order history
                        if !orders.isEmpty {
                            Text("Order History")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color(hex: "A6A29A"))
                                .padding(.top, 12)

                            ForEach(orders) { order in
                                orderRow(order)
                            }
                        }
                    }

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
        }
        .preferredColorScheme(.dark)
        .task { await loadData() }
        .sheet(isPresented: $showConfirm) { confirmSheet }
        .sheet(item: $checkoutURL) { url in
            SafariView(url: url)
        }
    }

    private func productCard(_ product: ClinicProduct) -> some View {
        Button {
            selectedProduct = product
            showConfirm = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: categoryIcon(product.category))
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "C8A96E"))
                    .frame(width: 44, height: 44)
                    .background(Color(hex: "C8A96E").opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 3) {
                    Text(product.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(hex: "F4F1E8"))
                    Text("\(product.typicalDose ?? "") · \(product.frequency ?? "")")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "A6A29A"))
                }
                Spacer()
                if let price = product.price {
                    Text("$\(String(format: "%.2f", price))")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "C8A96E"))
                }
            }
            .padding(16)
            .background(Color(hex: "111111"))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color(hex: "F4F1E8").opacity(0.06), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func orderRow(_ order: ReorderRequest) -> some View {
        HStack(spacing: 12) {
            Image(systemName: statusIcon(order.status))
                .foregroundColor(statusColor(order.status))
                .font(.system(size: 16))

            VStack(alignment: .leading, spacing: 2) {
                Text(order.productName ?? "Product")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "F4F1E8"))
                Text(order.status.capitalized)
                    .font(.system(size: 11))
                    .foregroundColor(statusColor(order.status))
            }
            Spacer()
            if let cents = order.amountCents, cents > 0 {
                Text("$\(String(format: "%.2f", Double(cents) / 100))")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color(hex: "A6A29A"))
            }
        }
        .padding(14)
        .background(Color(hex: "111111"))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var confirmSheet: some View {
        NavigationStack {
            ZStack {
                Color(hex: "070707").ignoresSafeArea()
                VStack(alignment: .leading, spacing: 16) {
                    if let p = selectedProduct {
                        Text(p.name)
                            .font(.system(size: 20, weight: .bold, design: .serif))
                            .foregroundColor(Color(hex: "F4F1E8"))

                        if let desc = p.description { Text(desc).font(.system(size: 13)).foregroundColor(Color(hex: "A6A29A")).lineSpacing(2) }

                        HStack(spacing: 16) {
                            VStack { Text("Dose").font(.system(size: 10)).foregroundColor(Color(hex: "6E6B65")); Text(p.typicalDose ?? "—").font(.system(size: 14, weight: .medium)).foregroundColor(Color(hex: "F4F1E8")) }
                            VStack { Text("Price").font(.system(size: 10)).foregroundColor(Color(hex: "6E6B65")); Text(p.price != nil ? "$\(String(format: "%.2f", p.price!))" : "—").font(.system(size: 14, weight: .semibold)).foregroundColor(Color(hex: "C8A96E")) }
                        }

                        TextField("Add a note for your clinician...", text: $orderNote, axis: .vertical)
                            .lineLimit(2...4)
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "F4F1E8"))
                            .padding(14)
                            .background(Color(hex: "111111"))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .tint(Color(hex: "C8A96E"))

                        GoldButton(label: "Request Refill") {
                            Task { await submitOrder(p) }
                        }
                    }
                    Spacer()
                }
                .padding(20)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { showConfirm = false }.foregroundColor(Color(hex: "A6A29A"))
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Data

    private func loadData() async {
        guard let token = await AuthService.shared.accessToken else { isLoading = false; return }

        // Load products from linked clinic
        if let url = URL(string: "\(baseURL)/api/clinic/products") {
            var req = URLRequest(url: url)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            // Products endpoint returns clinician's products — for patients we need a different approach
            // For now, load via care relationship
        }

        // Load orders
        if let url = URL(string: "\(baseURL)/api/consumer/reorder") {
            var req = URLRequest(url: url)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            if let (data, _) = try? await URLSession.shared.data(for: req) {
                struct Resp: Codable { let orders: [ReorderRequest] }
                if let resp = try? JSONDecoder().decode(Resp.self, from: data) {
                    orders = resp.orders
                }
            }
        }

        // Load clinic products via Supabase directly (patient has RLS read access)
        // We'll use the products from the linked clinician
        let supabase = SupabaseService.shared
        do {
            let response: [ClinicProduct] = try await supabase
                .from("clinic_products")
                .select()
                .eq("is_active", value: true)
                .execute()
                .value
            products = response
        } catch {
            print("[Reorder] Load products failed: \(error.localizedDescription)")
        }

        isLoading = false
    }

    private func submitOrder(_ product: ClinicProduct) async {
        guard let token = await AuthService.shared.accessToken,
              let url = URL(string: "\(baseURL)/api/consumer/reorder") else { return }

        let payload: [String: Any] = [
            "clinic_product_id": product.id.uuidString,
            "quantity": 1,
            "note": orderNote,
        ]

        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = body

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            struct Resp: Codable { let checkout_url: String? }
            if let resp = try? JSONDecoder().decode(Resp.self, from: data),
               let urlStr = resp.checkout_url,
               let url = URL(string: urlStr) {
                showConfirm = false
                checkoutURL = url
            } else {
                showConfirm = false
                await loadData() // Refresh
            }
        } catch {
            print("[Reorder] Submit failed: \(error.localizedDescription)")
        }
    }

    private func categoryIcon(_ cat: String) -> String {
        switch cat {
        case "peptide": return "syringe"
        case "supplement": return "pills"
        case "medication": return "pills.fill"
        case "service": return "stethoscope"
        case "lab_test": return "testtube.2"
        default: return "shippingbox"
        }
    }

    private func statusIcon(_ s: String) -> String {
        switch s {
        case "fulfilled": return "checkmark.circle.fill"
        case "approved": return "clock.fill"
        case "rejected": return "xmark.circle.fill"
        case "cancelled": return "xmark.circle"
        default: return "arrow.clockwise"
        }
    }

    private func statusColor(_ s: String) -> Color {
        switch s {
        case "fulfilled": return Color(hex: "7A8771")
        case "approved": return Color(hex: "C8A96E")
        case "rejected", "cancelled": return Color(hex: "C26B5A")
        default: return Color(hex: "A6A29A")
        }
    }
}

// MARK: - Models

struct ClinicProduct: Identifiable, Codable {
    let id: UUID
    let name: String
    let category: String
    let description: String?
    let typicalDose: String?
    let frequency: String?
    let method: String?
    let price: Double?
    let priceUnit: String?
    let inStock: Bool?

    enum CodingKeys: String, CodingKey {
        case id, name, category, description, frequency, method, price
        case typicalDose = "typical_dose"
        case priceUnit = "price_unit"
        case inStock = "in_stock"
    }
}

struct ReorderRequest: Identifiable, Codable {
    let id: UUID
    let status: String
    let quantity: Int?
    let amountCents: Int?
    let patientNote: String?
    let clinicianNote: String?
    let createdAt: String?
    var productName: String? // enriched

    enum CodingKeys: String, CodingKey {
        case id, status, quantity
        case amountCents = "amount_cents"
        case patientNote = "patient_note"
        case clinicianNote = "clinician_note"
        case createdAt = "created_at"
        case productName = "product_name"
    }
}

// Safari view for Stripe checkout
import SafariServices

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
