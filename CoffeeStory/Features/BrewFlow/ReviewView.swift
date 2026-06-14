import SwiftUI

struct ReviewView: View {
    let controller: BrewFlowController
    var onSaved: () -> Void

    @State private var record = false
    @State private var scores = FlavorScores()
    @State private var takeaway = ""
    @State private var tweaks: [NextTweak] = []
    @State private var note = ""
    @State private var markBest = false

    private var session: ActiveBrewSession { controller.session }

    var body: some View {
        ScrollView {
            VStack(spacing: Space.lg) {
                paramsRecap
                FlavorScoreEditor(record: $record, scores: $scores).surfaceCard()
                TakeawayEditor(text: $takeaway).surfaceCard()
                NextTweakEditor(tweaks: $tweaks, note: $note).surfaceCard()

                Toggle(isOn: $markBest.animation()) {
                    Label("设为这包的最佳参数", systemImage: "star.fill")
                        .font(.headline)
                        .foregroundStyle(markBest ? DT.gold : DT.ink)
                }
                .tint(DT.gold)
                .surfaceCard()
            }
            .padding(.horizontal, Space.xl)
            .padding(.vertical, Space.lg)
        }
        .safeAreaInset(edge: .bottom) {
            Button { commit() } label: {
                Label("保存这一杯", systemImage: "checkmark")
                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 4)
            }
            .buttonStyle(.glassProminent)
            .tint(DT.amber)
            .padding(.horizontal, Space.xl)
            .padding(.bottom, Space.sm)
        }
        .onAppear(perform: load)
    }

    private var paramsRecap: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text("这一杯").font(.headline).foregroundStyle(DT.ink)
            HStack(spacing: Space.md) {
                stat("研磨", NumFmt.g(session.grind))
                stat("粉水比", NumFmt.ratio(session.ratio))
                if let t = session.temp { stat("水温", "\(NumFmt.g(t))℃") }
                stat("总时间", TimeFmt.mmss(session.capturedTotalTime))
            }
        }
        .surfaceCard()
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.roundedNumber(17, weight: .bold)).foregroundStyle(DT.ink)
            Text(title).font(.caption2).foregroundStyle(DT.inkTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.sm)
        .background(DT.surfaceSunken, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
    }

    private func load() {
        record = session.overall != nil || session.acidity != nil
        scores = FlavorScores(
            acidity: session.acidity ?? 3,
            sweetness: session.sweetness ?? 3,
            body: session.bodyScore ?? 3,
            aftertaste: session.aftertaste ?? 3,
            balance: session.balance ?? 3,
            overall: session.overall ?? 3.5
        )
        takeaway = session.takeaway
        tweaks = session.nextTweaks
        note = session.nextTweakNote
        markBest = session.markBest
    }

    private func commit() {
        session.acidity = record ? scores.acidity : nil
        session.sweetness = record ? scores.sweetness : nil
        session.bodyScore = record ? scores.body : nil
        session.aftertaste = record ? scores.aftertaste : nil
        session.balance = record ? scores.balance : nil
        session.overall = record ? scores.overall : nil
        session.takeaway = takeaway.trimmingCharacters(in: .whitespaces)
        session.nextTweaks = tweaks
        session.nextTweakNote = note.trimmingCharacters(in: .whitespaces)
        session.markBest = markBest
        controller.save()
        onSaved()
    }
}
