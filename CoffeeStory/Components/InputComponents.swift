import SwiftUI

// MARK: - 数值步进字段
struct StepperField: View {
    let title: String
    var unit: String = ""
    @Binding var value: Double
    var range: ClosedRange<Double>
    var step: Double
    var format: (Double) -> String = { NumFmt.g($0) }
    var tint: Color = DT.amber
    var compact: Bool = false

    // 紧凑模式尺寸
    private var valueSize: CGFloat { compact ? 18 : 26 }
    private var btnSize: CGFloat { compact ? 32 : 40 }
    private var padding: CGFloat { compact ? Space.sm : Space.md }
    private var spacing: CGFloat { compact ? Space.xs : Space.md }

    private func change(_ delta: Double) {
        let v = (value + delta).clampedTo(range)
        if v != value { Haptics.selection() }
        value = (v / step).rounded() * step
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(title)
                .font(compact ? .caption2 : .footnote)
                .foregroundStyle(DT.inkSecondary)
            HStack(spacing: spacing) {
                stepButton("minus") { change(-step) }
                Spacer(minLength: 0)
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(format(value)).font(.roundedNumber(valueSize, weight: .semibold))
                    if !unit.isEmpty {
                        Text(unit).font(compact ? .caption2 : .footnote).foregroundStyle(DT.inkTertiary)
                    }
                }
                .foregroundStyle(DT.ink)
                .contentTransition(.numericText())
                .animation(.snappy, value: value)
                Spacer(minLength: 0)
                stepButton("plus") { change(step) }
            }
        }
        .padding(padding)
        .background(DT.surfaceSunken, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(format(value)) \(unit)")
        .accessibilityAdjustableAction { dir in
            switch dir {
            case .increment: change(step)
            case .decrement: change(-step)
            default: break
            }
        }
    }

    private func stepButton(_ symbol: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: compact ? 13 : 15, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: btnSize, height: btnSize)
                .background(tint.opacity(0.14), in: Circle())
        }
        .buttonStyle(.plain)
    }
}

extension Comparable {
    func clampedTo(_ range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
