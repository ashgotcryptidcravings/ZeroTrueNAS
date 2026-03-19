import SwiftUI

struct GridOverlay: View {
    var lineSpacing: CGFloat = 32
    var lineOpacity: Double = 0.04

    var body: some View {
        Canvas { context, size in
            // Vertical lines
            var x: CGFloat = 0
            while x < size.width {
                let path = Path { p in
                    p.move(to: CGPoint(x: x, y: 0))
                    p.addLine(to: CGPoint(x: x, y: size.height))
                }
                context.stroke(path, with: .color(Theme.cyan.opacity(lineOpacity)), lineWidth: 0.5)
                x += lineSpacing
            }

            // Horizontal lines
            var y: CGFloat = 0
            while y < size.height {
                let path = Path { p in
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(path, with: .color(Theme.cyan.opacity(lineOpacity)), lineWidth: 0.5)
                y += lineSpacing
            }
        }
        .allowsHitTesting(false)
    }
}

struct ScanlineOverlay: View {
    var body: some View {
        Canvas { context, size in
            var y: CGFloat = 0
            while y < size.height {
                let rect = CGRect(x: 0, y: y, width: size.width, height: 1)
                context.fill(Path(rect), with: .color(.black.opacity(0.08)))
                y += 3
            }
        }
        .allowsHitTesting(false)
    }
}
