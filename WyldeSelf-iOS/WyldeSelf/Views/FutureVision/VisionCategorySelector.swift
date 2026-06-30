import SwiftUI

struct VisionCategorySelector: View {
    @Binding var selected: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("CHOOSE YOUR CATEGORIES")
                .font(.system(size: 10, weight: .semibold))
                .tracking(2.5)
                .foregroundColor(VisionTheme.accent)

            Text("What areas of your future life do you want to see clearly?")
                .font(.system(size: 15))
                .foregroundColor(VisionTheme.textMuted)
                .lineSpacing(3)

            let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(VisionCategory.all) { cat in
                    CategoryCardButton(
                        category: cat,
                        isSelected: selected.contains(cat.id),
                        onTap: {
                            DispatchQueue.main.async {
                                if selected.contains(cat.id) {
                                    selected.remove(cat.id)
                                } else {
                                    selected.insert(cat.id)
                                }
                            }
                        }
                    )
                }
            }
        }
    }
}

// Separate view to isolate state changes
struct CategoryCardButton: View {
    let category: VisionCategory
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 10) {
                Image(systemName: category.icon)
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? VisionTheme.accent : VisionTheme.textFaint)

                Text(category.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? VisionTheme.text : VisionTheme.textMuted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(isSelected ? VisionTheme.accent.opacity(0.08) : VisionTheme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? VisionTheme.borderActive : VisionTheme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
