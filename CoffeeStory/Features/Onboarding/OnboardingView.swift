import SwiftUI

struct OnboardingView: View {
    var onFinish: () -> Void
    @State private var page = 0

    private struct Slide: Identifiable {
        let id = UUID()
        let symbol: String
        let title: String
        let body: String
    }

    private let slides: [Slide] = [
        .init(symbol: "flask.fill",
              title: "这不是咖啡日记",
              body: "而是一间「调参实验室」——\n帮你把一包豆子越冲越好。"),
        .init(symbol: "chart.line.uptrend.xyaxis",
              title: "每包一条收敛曲线",
              body: "第一次太酸、第二次磨细、第三次降温……\n看着评分一次次爬上去。"),
        .init(symbol: "arrow.triangle.2.circlepath",
              title: "冲完就复盘",
              body: "打个分，记一句「下次怎么调」，\n下次冲煮自动带到你眼前。")
    ]

    var body: some View {
        ZStack {
            DT.canvas.ignoresSafeArea()
            VStack(spacing: 0) {
                TabView(selection: $page) {
                    ForEach(Array(slides.enumerated()), id: \.element.id) { idx, slide in
                        VStack(spacing: Space.xl) {
                            ZStack {
                                Circle().fill(DT.amberSoft).frame(width: 168, height: 168)
                                Image(systemName: slide.symbol)
                                    .font(.system(size: 68, weight: .regular))
                                    .foregroundStyle(DT.amber)
                            }
                            .padding(.bottom, Space.sm)
                            Text(slide.title)
                                .font(.largeTitle.weight(.bold))
                                .foregroundStyle(DT.ink)
                            Text(slide.body)
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(DT.inkSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, Space.xxl)
                        .tag(idx)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .interactive))

                Button {
                    if page < slides.count - 1 {
                        withAnimation { page += 1 }
                    } else {
                        onFinish()
                    }
                } label: {
                    Text(page < slides.count - 1 ? "继续" : "开始调豆")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .glassProminentButtonStyle()
                .tint(DT.amber)
                .padding(.horizontal, Space.xl)
                .padding(.bottom, Space.lg)

                Button("跳过", action: onFinish)
                    .font(.subheadline)
                    .foregroundStyle(DT.inkTertiary)
                    .padding(.bottom, Space.xl)
                    .opacity(page < slides.count - 1 ? 1 : 0)
            }
        }
    }
}
