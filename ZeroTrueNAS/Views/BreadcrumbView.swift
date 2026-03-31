import SwiftUI

struct BreadcrumbView: View {
    let path: String
    let onNavigate: (String) -> Void

    private var components: [(name: String, path: String)] {
        Formatters.pathComponents(path)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(Array(components.enumerated()), id: \.offset) { index, component in
                        if index > 0 {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(Theme.textMuted)
                        }

                        Button {
                            onNavigate(component.path)
                        } label: {
                            Text(component.name)
                                .font(Theme.monoFont(12))
                                .foregroundColor(index == components.count - 1 ? Theme.cyan : Theme.textSecondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(index == components.count - 1 ? Theme.cyan.opacity(0.08) : Color.clear)
                                )
                        }
                        .id(index)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .onChange(of: path) { _ in
                withAnimation {
                    proxy.scrollTo(components.count - 1, anchor: .trailing)
                }
            }
        }
        .background(Theme.background)
    }
}
