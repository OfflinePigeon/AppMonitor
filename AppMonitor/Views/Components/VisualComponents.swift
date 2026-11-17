import SwiftUI

/// Slim metric bar. `progress` is relative within the current visible list so
/// the ranking is visually comparable; the numeric label always carries the
/// absolute value.
struct ResourceBar: View {
    let progress: Double
    var tint: Color
    var height: CGFloat = 3

    var body: some View {
        GeometryReader { proxy in
            let clamped = min(max(progress, 0), 1)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.08))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.62), tint],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: clamped > 0 ? max(2, proxy.size.width * clamped) : 0)
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// A compact CPU history graph used in the detail inspector. Falls back to a
/// "collecting" placeholder until enough samples are available.
struct SparklineView: View {
    let values: [Double]
    var tint: Color = MetricPalette.cpu
    var height: CGFloat = 56

    var body: some View {
        Group {
            if values.count >= 2 {
                Canvas { context, size in
                    let maxValue = max(values.max() ?? 1, 1)
                    let stepX = size.width / CGFloat(max(values.count - 1, 1))
                    let points = values.enumerated().map { index, value -> CGPoint in
                        let x = CGFloat(index) * stepX
                        let normalized = min(max(value / maxValue, 0), 1)
                        let y = size.height - (CGFloat(normalized) * (size.height - 8)) - 4
                        return CGPoint(x: x, y: y)
                    }

                    var area = Path()
                    area.move(to: CGPoint(x: 0, y: size.height))
                    for point in points {
                        area.addLine(to: point)
                    }
                    area.addLine(to: CGPoint(x: size.width, y: size.height))
                    area.closeSubpath()

                    context.fill(
                        area,
                        with: .linearGradient(
                            Gradient(colors: [tint.opacity(0.28), tint.opacity(0.01)]),
                            startPoint: .zero,
                            endPoint: CGPoint(x: 0, y: size.height)
                        )
                    )

                    var line = Path()
                    if let first = points.first {
                        line.move(to: first)
                        for point in points.dropFirst() {
                            line.addLine(to: point)
                        }
                    }
                    context.stroke(
                        line,
                        with: .color(tint),
                        style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round)
                    )
                }
            } else {
                HStack(spacing: 7) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Collecting live samples…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .accessibilityLabel("CPU activity over time")
    }
}

/// Standard rounded surface used by inspector sections and list cards.
struct CardSurface: ViewModifier {
    var cornerRadius: CGFloat = 12
    var borderOpacity: Double = 0.07

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .shadow(color: Color.black.opacity(0.045), radius: 3, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(borderOpacity), lineWidth: 0.7)
            )
    }
}

extension View {
    func cardSurface(cornerRadius: CGFloat = 12, borderOpacity: Double = 0.07) -> some View {
        modifier(CardSurface(cornerRadius: cornerRadius, borderOpacity: borderOpacity))
    }
}
