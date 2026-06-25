import SwiftUI

// MARK: - 数值步进字段
struct StepperField: View {
    let title: String
    var unit: String = ""
    @Binding var value: Double
    var range: ClosedRange<Double>
    var step: Double
    var format: (Double) -> String = { NumFmt.g($0) }
    var parse: (String) -> Double? = { Double($0) }
    var tint: Color = DT.amber
    var compact: Bool = false

    // 紧凑模式尺寸
    private var valueSize: CGFloat { compact ? 18 : 26 }
    private var btnSize: CGFloat { compact ? 32 : 40 }
    private var padding: CGFloat { compact ? Space.sm : Space.md }
    private var spacing: CGFloat { compact ? Space.xs : Space.md }

    @State private var editing = false
    @State private var draft = ""

    private func change(_ delta: Double) {
        let v = (value + delta).clampedTo(range)
        if v != value { Haptics.selection() }
        value = (v / step).rounded() * step
    }

    private func beginEdit() {
        draft = format(value)
        editing = true
    }

    private func commitDraft() {
        let cleaned = draft.replacingOccurrences(of: "，", with: ".")
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        guard let raw = parse(cleaned) else { return }
        let snapped = ((raw.clampedTo(range)) / step).rounded() * step
        if snapped != value { Haptics.selection() }
        value = snapped
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(title)
                .font(compact ? .caption2 : .footnote)
                .foregroundStyle(DT.inkSecondary)
            HStack(spacing: spacing) {
                stepButton("minus") { change(-step) }
                Spacer(minLength: 0)
                Button(action: beginEdit) {
                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text(format(value)).font(.roundedNumber(valueSize, weight: .semibold))
                        if !unit.isEmpty {
                            Text(unit).font(compact ? .caption2 : .footnote).foregroundStyle(DT.inkTertiary)
                        }
                    }
                    .foregroundStyle(DT.ink)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: value)
                }
                .buttonStyle(.plain)
                Spacer(minLength: 0)
                stepButton("plus") { change(step) }
            }
        }
        .padding(padding)
        .background(DT.surfaceSunken, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
        .alert("\(title)\(unit.isEmpty ? "" : "（\(unit)）")", isPresented: $editing) {
            TextField("输入数值", text: $draft)
                .keyboardType(.decimalPad)
            Button("确定", action: commitDraft)
            Button("取消", role: .cancel) {}
        } message: {
            Text("范围 \(format(range.lowerBound))–\(format(range.upperBound))")
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(format(value)) \(unit)")
        .accessibilityHint("双击可直接输入数值")
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

extension Collection {
    /// 安全下标：越界返回 nil
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
