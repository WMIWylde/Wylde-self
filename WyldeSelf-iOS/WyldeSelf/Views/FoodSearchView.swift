import SwiftUI
import AVFoundation

struct FoodSearchView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var tracker = MacroTrackerService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var results: [SearchFood] = []
    @State private var portionFood: SearchFood?
    @State private var portionQty: Double = 1.0
    @State private var isSearching = false
    @State private var selectedMealType: MealType = .lunch
    @State private var showBarcode = false
    @State private var debounceTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Theme.appBG.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("LOG FOOD")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(2.5)
                        .foregroundColor(WyldeStyles.Colors.bronze)
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
                .padding(.horizontal, 20)
                .padding(.top, 16)

                // Search bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Theme.tertiaryText)
                    TextField("Search foods, brands, products...", text: $searchText)
                        .font(.system(size: 14))
                        .foregroundColor(Theme.primaryText)
                        .tint(WyldeStyles.Colors.bronze)
                        .autocorrectionDisabled()
                    if isSearching {
                        ProgressView().tint(WyldeStyles.Colors.bronze).scaleEffect(0.7)
                    }
                    if !searchText.isEmpty {
                        Button { searchText = ""; results = [] } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Theme.tertiaryText)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Theme.elevatedBG)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .onChange(of: searchText) {
                    debounceTask?.cancel()
                    debounceTask = Task {
                        try? await Task.sleep(nanoseconds: 350_000_000)
                        if !Task.isCancelled { await search() }
                    }
                }

                // Meal type
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(MealType.allCases, id: \.self) { type in
                            Button { selectedMealType = type } label: {
                                Text(type.rawValue)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(selectedMealType == type ? Theme.onAccent : Theme.secondaryText)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(selectedMealType == type ? WyldeStyles.Colors.bronze : Theme.chipBG)
                                    .clipShape(Capsule())
                            }
                        }
                        // Barcode button
                        Button { showBarcode = true } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "barcode.viewfinder")
                                    .font(.system(size: 13))
                                Text("Scan")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(WyldeStyles.Colors.vitalTeal)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(WyldeStyles.Colors.vitalTeal.opacity(0.10))
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.top, 10)

                // Results
                if results.isEmpty && !searchText.isEmpty && !isSearching {
                    VStack(spacing: 12) {
                        Spacer().frame(height: 40)
                        Image(systemName: "fork.knife")
                            .font(.system(size: 28))
                            .foregroundColor(Theme.tertiaryText)
                        Text("No results for \"\(searchText)\"")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.secondaryText)
                        Spacer()
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 8) {
                            ForEach(results) { food in
                                foodRow(food)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .sheet(isPresented: $showBarcode) {
            BarcodeScannerView { barcode in
                showBarcode = false
                searchText = barcode
                Task { await searchBarcode(barcode) }
            }
        }
        .sheet(item: Binding(
            get: { portionFood.map { PortionWrapper(food: $0) } },
            set: { if $0 == nil { portionFood = nil } }
        )) { wrapped in
            portionSheet(wrapped.food)
                .presentationDetents([.height(340)])
        }
    }

    private func foodRow(_ food: SearchFood) -> some View {
        Button {
            portionFood = food
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(food.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Theme.primaryText)
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        if let brand = food.brand {
                            Text(brand)
                                .font(.system(size: 11))
                                .foregroundColor(Theme.tertiaryText)
                                .lineLimit(1)
                        }
                        Text("\(food.servingSize ?? 100, specifier: "%.0f")\(food.servingUnit ?? "g")")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.tertiaryText)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(food.calories ?? 0)")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(WyldeStyles.Colors.bronze)
                    Text("cal")
                        .font(.system(size: 9))
                        .foregroundColor(Theme.tertiaryText)
                }
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(food.protein ?? 0, specifier: "%.0f")g")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(WyldeStyles.Colors.vitalTeal)
                    Text("P")
                        .font(.system(size: 9))
                        .foregroundColor(Theme.tertiaryText)
                }
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(WyldeStyles.Colors.bronze)
                    .font(.system(size: 20))
            }
            .padding(14)
            .background(Theme.elevatedBG)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Search

    private func search() async {
        guard searchText.count >= 2 else { results = []; return }
        isSearching = true
        defer { isSearching = false }

        guard let url = URL(string: "https://www.wyldeself.com/api/nutrition/search?q=\(searchText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? searchText)") else { return }

        do {
            var request = URLRequest(url: url)
            if let token = await AuthService.shared.accessToken {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            let (data, _) = try await URLSession.shared.data(for: request)
            struct Resp: Codable { let foods: [SearchFood] }
            let resp = try JSONDecoder().decode(Resp.self, from: data)
            results = resp.foods
        } catch {
            #if DEBUG
            print("[FoodSearch] Error: \(error.localizedDescription)")
            #endif
        }
    }

    private func searchBarcode(_ barcode: String) async {
        isSearching = true
        defer { isSearching = false }

        guard let url = URL(string: "https://www.wyldeself.com/api/nutrition/search?barcode=\(barcode)") else { return }

        do {
            let (data, _) = try await { () -> (Data, URLResponse) in
                var request = URLRequest(url: url)
                if let token = await AuthService.shared.accessToken {
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                }
                return try await URLSession.shared.data(for: request)
            }()
            struct Resp: Codable { let foods: [SearchFood] }
            let resp = try JSONDecoder().decode(Resp.self, from: data)
            results = resp.foods
        } catch {
            #if DEBUG
            print("[FoodSearch] Barcode error: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Log

    @ViewBuilder
    private func portionSheet(_ food: SearchFood) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(food.name)
                .font(.system(size: 18, weight: .semibold, design: .serif))
                .foregroundColor(WyldeStyles.Colors.ink)
                .lineLimit(2)

            if let size = food.servingSize, let unit = food.servingUnit {
                Text("1 serving = \(size.clean) \(unit)")
                    .font(.system(size: 12))
                    .foregroundColor(WyldeStyles.Colors.stone)
            }

            Text("HOW MUCH?")
                .font(.system(size: 10, weight: .semibold))
                .tracking(2)
                .foregroundColor(WyldeStyles.Colors.stone)

            HStack(spacing: 8) {
                ForEach([0.25, 0.5, 1.0, 1.5, 2.0], id: \.self) { q in
                    Button {
                        portionQty = q
                    } label: {
                        Text(q.clean + "×")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(portionQty == q ? WyldeStyles.Colors.paper : WyldeStyles.Colors.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(portionQty == q ? WyldeStyles.Colors.ink : WyldeStyles.Colors.bone)
                            .clipShape(Capsule())
                    }
                }
            }

            HStack {
                Text("Custom:")
                    .font(.system(size: 13))
                    .foregroundColor(WyldeStyles.Colors.stone)
                Slider(value: $portionQty, in: 0.25...4, step: 0.25)
                    .tint(WyldeStyles.Colors.sage)
                Text(portionQty.clean + "×")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(WyldeStyles.Colors.ink)
                    .frame(width: 50)
            }

            Text("\(Int(Double(food.calories ?? 0) * portionQty)) cal · \(Int((food.protein ?? 0) * portionQty))g protein")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(WyldeStyles.Colors.bronze)

            Button {
                logFood(food, quantity: portionQty)
                portionFood = nil
                portionQty = 1.0
            } label: {
                Text("Log It")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(WyldeStyles.Colors.paper)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(WyldeStyles.Colors.ink)
                    .clipShape(Capsule())
            }
        }
        .padding(20)
        .background(Theme.appBG)
    }

    private func logFood(_ food: SearchFood, quantity: Double = 1.0) {
        let qLabel = quantity == 1.0 ? food.name : "\(quantity.clean)\u{00D7} \(food.name)"
        let analysis = FoodAnalysis(
            description: qLabel,
            calories: Int(Double(food.calories ?? 0) * quantity),
            protein: Int((food.protein ?? 0) * quantity),
            carbs: Int((food.carbs ?? 0) * quantity),
            fat: Int((food.fat ?? 0) * quantity),
            items: []
        )
        tracker.addMeal(name: qLabel, analysis: analysis, mealType: selectedMealType)
        appState.proteinLogged = tracker.totalProtein
        appState.caloriesLogged = tracker.totalCalories
        appState.carbsLogged = tracker.totalCarbs
        appState.fatLogged = tracker.totalFat
        HapticManager.shared.notification(.success)
        dismiss()
    }
}

// MARK: - Models

struct SearchFood: Identifiable, Codable {
    let id: UUID?
    let name: String
    let brand: String?
    let servingSize: Double?
    let servingUnit: String?
    let calories: Int?
    let protein: Double?
    let carbs: Double?
    let fat: Double?
    let fiber: Double?
    let sugar: Double?
    let barcode: String?

    enum CodingKeys: String, CodingKey {
        case id, name, brand, calories, protein, carbs, fat, fiber, sugar, barcode
        case servingSize = "serving_size"
        case servingUnit = "serving_unit"
    }
}

// MARK: - Barcode Scanner

struct BarcodeScannerView: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    func makeUIViewController(context: Context) -> BarcodeScannerVC {
        let vc = BarcodeScannerVC()
        vc.onScan = onScan
        return vc
    }
    func updateUIViewController(_ vc: BarcodeScannerVC, context: Context) {}
}

class BarcodeScannerVC: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onScan: ((String) -> Void)?
    private let session = AVCaptureSession()
    private var found = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else { return }

        if session.canAddInput(input) { session.addInput(input) }

        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.ean8, .ean13, .upce, .code128, .code39]
        }

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.frame = view.bounds
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput results: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !found, let obj = results.first as? AVMetadataMachineReadableCodeObject, let code = obj.stringValue else { return }
        found = true
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        session.stopRunning()
        onScan?(code)
        dismiss(animated: true)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        session.stopRunning()
    }
}


private struct PortionWrapper: Identifiable {
    let food: SearchFood
    var id: String { food.name }
}

private extension Double {
    /// "0.5" -> "½-friendly" plain formatting: trims trailing zeros.
    var clean: String {
        self == floor(self) ? String(Int(self)) : String(format: "%.2g", self)
    }
}
