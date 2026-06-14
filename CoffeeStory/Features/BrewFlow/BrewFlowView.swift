import SwiftUI
import SwiftData

struct BrewFlowView: View {
    @Bindable var session: ActiveBrewSession
    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router
    @Query private var beans: [Bean]

    @State private var controller: BrewFlowController?
    @State private var showExit = false
    @State private var showGraduate = false

    private var bean: Bean? { beans.first { $0.id == session.beanID } }

    var body: some View {
        ZStack {
            DT.canvas.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                if let controller {
                    Group {
                        switch session.phase {
                        case .prepare: PrepareView(controller: controller, session: session)
                        case .brewing: BrewingView(controller: controller)
                        case .review:  ReviewView(controller: controller, onSaved: handleSaved)
                        }
                    }
                    .transition(.opacity)
                } else {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }
        }
        .onAppear {
            if controller == nil, let bean {
                controller = BrewFlowController(session: session, bean: bean, context: context)
            }
            if bean == nil { close() }
        }
        .interactiveDismissDisabled(true)
        .confirmationDialog("退出这次冲煮？", isPresented: $showExit, titleVisibility: .visible) {
            Button("退出，不保存", role: .destructive) {
                controller?.discard()
                close()
            }
            Button("继续冲煮", role: .cancel) {}
        } message: {
            Text("当前这次冲煮将不会被保存。")
        }
        .confirmationDialog("这包喝完了 🎓", isPresented: $showGraduate, titleVisibility: .visible) {
            Button(controller?.bean.bestBrew == nil ? "毕业（未标记最佳）" : "存入配方并毕业") {
                controller?.graduateBean()
                close()
            }
            Button("暂不", role: .cancel) { close() }
        } message: {
            Text("剩余克数已归零。要把最佳配方存进配方库吗？")
        }
    }

    private var topBar: some View {
        HStack {
            Button { showExit = true } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(DT.inkSecondary)
                    .frame(width: 40, height: 40)
            }
            Spacer()
            VStack(spacing: 1) {
                Text(bean?.name ?? "").font(.subheadline.weight(.semibold)).foregroundStyle(DT.ink)
                Text("第 \(controller?.attemptNumber ?? 0) 次").font(.caption2).foregroundStyle(DT.inkTertiary)
            }
            Spacer()
            phaseDots.frame(width: 40)
        }
        .padding(.horizontal, Space.lg)
        .padding(.top, Space.sm)
    }

    private var phaseDots: some View {
        HStack(spacing: 5) {
            ForEach([BrewPhase.prepare, .brewing, .review], id: \.self) { p in
                Circle()
                    .fill(p == session.phase ? DT.amber : DT.inkTertiary.opacity(0.4))
                    .frame(width: 6, height: 6)
            }
        }
    }

    private func handleSaved() {
        if controller?.didGraduate == true {
            showGraduate = true
        } else {
            close()
        }
    }

    private func close() {
        router.presentedSession = nil
    }
}
