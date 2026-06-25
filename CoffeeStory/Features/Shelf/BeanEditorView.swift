import SwiftUI
import SwiftData
import PhotosUI

struct BeanEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    var editing: Bean?
    var prefill: RecipeArchive?

    @State private var name = ""
    @State private var bagWeight: Double = 200
    @State private var roaster = ""
    @State private var origin = ""
    @State private var process: Process = .washed
    @State private var roast: RoastLevel = .mediumLight
    @State private var hasRoastDate = false
    @State private var roastDate = Date()
    @State private var grinderNote = ""
    @State private var notes = ""
    @State private var tags: [String] = []
    @State private var newTag = ""
    @State private var coverData: Data?
    @State private var pickerItem: PhotosPickerItem?
    @State private var showPickerOptions = false
    @State private var showLibrary = false
    @State private var showCamera = false
    @State private var cameraImage: UIImage?

    private var valid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && bagWeight >= 1
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: Space.lg) {
                        Button { showPickerOptions = true } label: {
                            ZStack(alignment: .bottomTrailing) {
                                BeanCover(data: coverData, size: 64)
                                Image(systemName: "camera.fill")
                                    .font(.caption2)
                                    .padding(5)
                                    .background(DT.amber, in: Circle())
                                    .foregroundStyle(.white)
                                    .offset(x: 4, y: 4)
                            }
                        }
                        .confirmationDialog("选择照片", isPresented: $showPickerOptions) {
                            Button("拍照") { showCamera = true }
                            Button("从相册选择") { showLibrary = true }
                            Button("取消", role: .cancel) {}
                        } message: {
                            Text("点左侧拍/选豆袋照片")
                        }
                        .photosPicker(isPresented: $showLibrary, selection: $pickerItem, matching: .images)
                        .fullScreenCover(isPresented: $showCamera) {
                            CameraPicker(image: $cameraImage)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("给这包起个名", text: $name)
                                .font(.headline)
                            Text("点左侧拍/选豆袋照片")
                                .font(.caption).foregroundStyle(DT.inkTertiary)
                        }
                    }
                    LabeledContent("净含量") {
                        HStack {
                            TextField("克", value: $bagWeight, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                            Text("g").foregroundStyle(DT.inkTertiary)
                        }
                    }
                }

                Section("风味来源") {
                    TextField("产区 / 庄园（如 埃塞 耶加雪菲）", text: $origin)
                    Picker("处理法", selection: $process) {
                        ForEach(Process.allCases) { Text($0.label).tag($0) }
                    }
                    Picker("烘焙度", selection: $roast) {
                        ForEach(RoastLevel.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Toggle("记录烘焙日期", isOn: $hasRoastDate)
                    if hasRoastDate {
                        DatePicker("烘焙日期", selection: $roastDate, in: ...Date(), displayedComponents: .date)
                    }
                    tagEditor
                }

                Section("其它") {
                    TextField("烘焙商", text: $roaster)
                    TextField("磨豆机 / 刻度说明（如 C40 · 24格）", text: $grinderNote)
                    TextField("备注", text: $notes, axis: .vertical).lineLimit(2...4)
                }
            }
            .navigationTitle(editing == nil ? "新建豆子" : "编辑豆子")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }.disabled(!valid)
                }
            }
            .onAppear(perform: load)
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        coverData = ImageTool.downscaledJPEG(data)
                    }
                }
            }
            .onChange(of: cameraImage) { _, image in
                guard let image, let data = image.jpegData(compressionQuality: 1) else { return }
                coverData = ImageTool.downscaledJPEG(data)
            }
        }
    }

    private var tagEditor: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack {
                TextField("加风味标签（莓果 / 柑橘 …）", text: $newTag)
                    .onSubmit(addTag)
                Button(action: addTag) { Image(systemName: "plus.circle.fill") }
                    .disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            if !tags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(tags, id: \.self) { tag in
                        Button { tags.removeAll { $0 == tag } } label: {
                            HStack(spacing: 3) {
                                Text(tag); Image(systemName: "xmark")
                            }
                            .font(.caption)
                            .padding(.horizontal, 9).padding(.vertical, 5)
                            .background(DT.amberSoft, in: Capsule())
                            .foregroundStyle(DT.coffee)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func addTag() {
        let t = newTag.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty, !tags.contains(t) else { return }
        tags.append(t); newTag = ""
    }

    private func load() {
        guard let bean = editing else {
            if let p = prefill {
                origin = p.originText
                process = p.process
                roast = p.roastLevel
                tags = p.flavorTags
            }
            return
        }
        name = bean.name
        bagWeight = bean.bagWeightGrams
        roaster = bean.roaster
        origin = bean.originText
        process = bean.process
        roast = bean.roastLevel
        if let d = bean.roastDate { hasRoastDate = true; roastDate = d }
        grinderNote = bean.grinderNote
        notes = bean.notes
        tags = bean.flavorTags
        coverData = bean.coverImageData
    }

    private func save() {
        let bean = editing ?? Bean(name: "", bagWeightGrams: bagWeight)
        let wasNew = editing == nil
        bean.name = name.trimmingCharacters(in: .whitespaces)
        if wasNew {
            bean.remainingGrams = bagWeight
        }
        bean.bagWeightGrams = bagWeight
        bean.roaster = roaster
        bean.originText = origin.trimmingCharacters(in: .whitespaces)
        bean.process = process
        bean.roastLevel = roast
        bean.roastDate = hasRoastDate ? roastDate : nil
        bean.grinderNote = grinderNote
        bean.notes = notes
        bean.flavorTags = tags
        bean.coverImageData = coverData
        if wasNew { context.insert(bean) }
        Haptics.success()
        dismiss()
    }
}

// MARK: - 拍照
struct CameraPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_: UIImagePickerController, context _: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any])
        {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - 图片处理
enum ImageTool {
    static func downscaledJPEG(_ data: Data, maxEdge: CGFloat = 1600, quality: CGFloat = 0.8) -> Data? {
        guard let img = UIImage(data: data) else { return nil }
        let longest = max(img.size.width, img.size.height)
        let scale = min(1, maxEdge / longest)
        let newSize = CGSize(width: img.size.width * scale, height: img.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let out = renderer.image { _ in img.draw(in: CGRect(origin: .zero, size: newSize)) }
        return out.jpegData(compressionQuality: quality)
    }
}
