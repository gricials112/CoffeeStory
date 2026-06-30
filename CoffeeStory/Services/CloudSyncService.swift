import CloudKit
import CryptoKit
import Foundation
import Observation
import SwiftData
import UIKit

enum CloudSyncStatus: Equatable {
    case off
    case idle
    case syncing(String)
    case synced(Date)
    case unavailable(String)
    case failed(String)

    var label: String {
        switch self {
        case .off: "Pro 专属"
        case .idle: "等待同步"
        case .syncing: "同步中"
        case .synced(let date): "已同步 \(Self.relativeTime(date))"
        case .unavailable(let message): message
        case .failed: "同步失败"
        }
    }

    var detail: String {
        switch self {
        case .off: "升级 Pro 后自动使用 iCloud 私有数据库保留数据"
        case .idle: "开启后会在数据变化、启动和回到前台时自动同步"
        case .syncing(let reason): reason
        case .synced(let date): "上次同步：\(Self.fullTime(date))"
        case .unavailable(let message): message
        case .failed(let message): message
        }
    }

    var symbol: String {
        switch self {
        case .off: "lock.fill"
        case .idle: "icloud"
        case .syncing: "arrow.triangle.2.circlepath.icloud"
        case .synced: "checkmark.icloud.fill"
        case .unavailable: "exclamationmark.icloud"
        case .failed: "xmark.icloud"
        }
    }

    private static func relativeTime(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "刚刚" }
        if seconds < 3600 { return "\(seconds / 60) 分钟前" }
        if seconds < 86400 { return "\(seconds / 3600) 小时前" }
        return "\(seconds / 86400) 天前"
    }

    private static func fullTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

extension Notification.Name {
    static let coffeeStoryCloudKitDidChange = Notification.Name("coffeeStoryCloudKitDidChange")
}

@MainActor
@Observable
final class CloudSyncService {
    static let containerIdentifier = "iCloud.com.coffestory.coffeestory"

    var status: CloudSyncStatus = .idle
    var lastSyncedAt: Date?
    var lastSyncError: String?

    @ObservationIgnored private let container = CKContainer(identifier: CloudSyncService.containerIdentifier)
    @ObservationIgnored private let stateStore = CloudSyncStateStore()
    @ObservationIgnored private var debounceTask: Task<Void, Never>?
    @ObservationIgnored private var syncTask: Task<Void, Never>?
    @ObservationIgnored private var pendingSync = false
    @ObservationIgnored private var subscriptionsPrepared = false

    var isSyncing: Bool {
        if case .syncing = status { return true }
        return false
    }

    func updateProStatus(_ isPro: Bool) {
        guard !isPro else {
            if case .off = status { status = .idle }
            return
        }
        debounceTask?.cancel()
        pendingSync = false
        status = .off
    }

    func scheduleSync(isPro: Bool, context: ModelContext, reason: String, delay: TimeInterval = 1.5) {
        guard isPro else {
            updateProStatus(false)
            return
        }
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            guard let self else { return }
            let nanoseconds = UInt64(max(0, delay) * 1_000_000_000)
            if nanoseconds > 0 {
                try? await Task.sleep(nanoseconds: nanoseconds)
            }
            await self.syncNow(isPro: isPro, context: context, reason: reason)
        }
    }

    func syncNow(isPro: Bool, context: ModelContext, reason: String = "手动同步") async {
        guard isPro else {
            updateProStatus(false)
            return
        }
        updateProStatus(true)

        guard syncTask == nil else {
            pendingSync = true
            return
        }

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.performSync(context: context, reason: reason)
        }
        syncTask = task
        await task.value
        syncTask = nil

        if pendingSync {
            pendingSync = false
            scheduleSync(isPro: isPro, context: context, reason: "继续处理未完成变更", delay: 0.5)
        }
    }

    static func localDataFingerprint(beans: [Bean], brews: [Brew], recipes: [RecipeArchive]) -> String {
        var data = Data()
        let beanPayloads = beans.map(CloudBeanPayload.init(bean:)).sorted { $0.id.uuidString < $1.id.uuidString }
        let brewPayloads = brews.compactMap(CloudBrewPayload.init(brew:)).sorted { $0.id.uuidString < $1.id.uuidString }
        let recipePayloads = recipes.map(CloudRecipePayload.init(recipe:)).sorted { $0.id.uuidString < $1.id.uuidString }

        for payload in beanPayloads {
            if let encoded = try? makeEncoder().encode(payload) {
                data.append(encoded)
                data.append(0)
            }
        }
        for payload in brewPayloads {
            if let encoded = try? makeEncoder().encode(payload) {
                data.append(encoded)
                data.append(0)
            }
        }
        for payload in recipePayloads {
            if let encoded = try? makeEncoder().encode(payload) {
                data.append(encoded)
                data.append(0)
            }
        }
        return sha256Hex(data)
    }

    private func performSync(context: ModelContext, reason: String) async {
        print("[CloudSync] 开始同步: \(reason)")
        status = .syncing(reason)

        do {
            try context.save()
            print("[CloudSync] 本地数据已保存")

            try await verifyAccount()
            print("[CloudSync] iCloud 账号验证通过")

            // 首次同步时初始化 CloudKit schema（确保 record type 已存在）
            try? await initializeSchema()

            do { try await ensureSubscriptions() } catch {
                print("[CloudSync] 订阅设置失败（不影响同步）: \(error.localizedDescription)")
                logSyncError("[CloudSync] 订阅设置失败: \(error.localizedDescription)")
            }

            let iCloudUserRecordName = try await retryCloudKit {
                try await self.container.userRecordID().recordName
            }
            print("[CloudSync] 用户标识: \(iCloudUserRecordName)")

            let now = Date()
            var priorState = stateStore.load()
            if priorState.iCloudUserRecordName != nil,
               priorState.iCloudUserRecordName != iCloudUserRecordName {
                print("[CloudSync] 检测到 iCloud 账号变更，重置同步状态")
                priorState = CloudSyncStoredState(iCloudUserRecordName: iCloudUserRecordName)
            } else {
                priorState.iCloudUserRecordName = iCloudUserRecordName
            }

            let remoteRecords = try await fetchRemoteRecords()
            print("[CloudSync] 远端记录数: \(remoteRecords.count)")
            var workingState = priorState
            let localBeforePull = try makeLocalSnapshots(context: context, state: workingState, now: now)
            print("[CloudSync] 本地快照数: \(localBeforePull.count)")

            try applyRemoteChanges(
                remoteRecords: remoteRecords,
                localSnapshots: localBeforePull,
                state: &workingState,
                context: context
            )
            print("[CloudSync] 远端变更已应用到本地")

            let localAfterPull = try makeLocalSnapshots(context: context, state: workingState, now: Date())
            try await pushLocalChanges(
                localSnapshots: localAfterPull,
                remoteRecords: remoteRecords,
                priorState: priorState
            )
            print("[CloudSync] 本地变更已推送到云端")

            var newState = CloudSyncStoredState(
                lastSyncedAt: Date(),
                iCloudUserRecordName: iCloudUserRecordName,
                entities: [:]
            )
            for snapshot in localAfterPull.values {
                newState.entities[snapshot.key] = CloudSyncStoredEntity(
                    payloadHash: snapshot.payloadHash,
                    clientUpdatedAt: snapshot.clientUpdatedAt,
                    knownRemote: true
                )
            }
            stateStore.save(newState)
            lastSyncedAt = newState.lastSyncedAt
            lastSyncError = nil
            status = .synced(newState.lastSyncedAt ?? Date())
            print("[CloudSync] ✅ 同步完成")
        } catch let error as CloudSyncError {
            let msg = error.localizedDescription
            print("[CloudSync] ❌ 同步失败（iCloud 不可用）: \(msg)")
            logSyncError(msg)
            status = .unavailable(msg)
        } catch {
            let msg = error.localizedDescription
            print("[CloudSync] ❌ 同步失败: \(msg)")
            logSyncError(msg)
            status = .failed(msg)
        }
    }

    /// 记录同步错误到 UI 状态和持久化存储
    private func logSyncError(_ message: String) {
        lastSyncError = message
        UserDefaults.standard.set(message, forKey: "cloudSync.lastError")
    }

    /// 初始化 CloudKit schema：保存一条空记录让 CloudKit 自动创建 record type
    private func initializeSchema() async throws {
        for kind in CloudSyncEntityKind.allCases {
            let recordID = CKRecord.ID(recordName: ".schema-init-\(kind.rawValue)")
            let record = CKRecord(recordType: kind.recordType, recordID: recordID)
            record[CloudRecordField.entityID] = "" as NSString
            record[CloudRecordField.payloadHash] = "" as NSString
            record[CloudRecordField.clientUpdatedAt] = Date.distantPast as NSDate
            do {
                _ = try await database.save(record)
                try? await database.deleteRecord(withID: recordID)
                print("[CloudSync] Schema 初始化: \(kind.recordType)")
            } catch {
                print("[CloudSync] Schema 初始化 \(kind.recordType) 跳过: \(error.localizedDescription)")
            }
        }
    }

    private func verifyAccount() async throws {
        let accountStatus = try await retryCloudKit {
            try await self.container.accountStatus()
        }
        guard accountStatus == .available else {
            throw CloudSyncError.iCloudUnavailable(accountStatus.message)
        }
    }

    private func ensureSubscriptions() async throws {
        guard !subscriptionsPrepared else { return }
        UIApplication.shared.registerForRemoteNotifications()

        let existingSubscriptions = try await database.allSubscriptions()
        let existingIDs = Set(existingSubscriptions.map(\.subscriptionID))

        for kind in CloudSyncEntityKind.allCases {
            let subID = "coffeestory.\(kind.rawValue).changes.v1"
            guard !existingIDs.contains(subID) else { continue }
            let subscription = CKQuerySubscription(
                recordType: kind.recordType,
                predicate: NSPredicate(value: true),
                subscriptionID: subID,
                options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
            )
            let info = CKSubscription.NotificationInfo()
            info.shouldSendContentAvailable = true
            subscription.notificationInfo = info
            try await database.save(subscription)
        }
        subscriptionsPrepared = true
    }

    private var database: CKDatabase {
        container.privateCloudDatabase
    }

    /// 对 CloudKit 可重试的临时错误进行指数退避重试
    private func retryCloudKit<T>(
        maxRetries: Int = 3,
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        for attempt in 0..<maxRetries {
            do {
                return try await operation()
            } catch {
                lastError = error
                guard let ckError = error as? CKError else { throw error }
                switch ckError.code {
                case .networkFailure, .networkUnavailable, .requestRateLimited,
                     .zoneBusy, .serviceUnavailable, .operationCancelled:
                    let delay = min(pow(2, Double(attempt)), 30.0)
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                default:
                    throw error
                }
            }
        }
        throw lastError!
    }

    private func fetchRemoteRecords() async throws -> [String: RemoteCloudRecord] {
        var records: [String: RemoteCloudRecord] = [:]

        for kind in CloudSyncEntityKind.allCases {
            let query = CKQuery(recordType: kind.recordType, predicate: NSPredicate(value: true))
            var cursor: CKQueryOperation.Cursor?

            repeat {
                let page: (matchResults: [(CKRecord.ID, Result<CKRecord, Error>)], queryCursor: CKQueryOperation.Cursor?)
                if let cursor {
                    page = try await retryCloudKit {
                        try await self.database.records(continuingMatchFrom: cursor, resultsLimit: 200)
                    }
                } else {
                    page = try await retryCloudKit {
                        try await self.database.records(matching: query, resultsLimit: 200)
                    }
                }

                for (_, result) in page.matchResults {
                    switch result {
                    case .success(let record):
                        guard let remote = RemoteCloudRecord(kind: kind, record: record) else { continue }
                        records[remote.key] = remote
                    case .failure:
                        continue // 跳过单条获取失败的记录，不影响整体
                    }
                }
                cursor = page.queryCursor
            } while cursor != nil
        }

        return records
    }

    private func applyRemoteChanges(
        remoteRecords: [String: RemoteCloudRecord],
        localSnapshots: [String: LocalCloudSnapshot],
        state: inout CloudSyncStoredState,
        context: ModelContext
    ) throws {
        var remoteToApply: [RemoteCloudRecord] = []
        var localKeysToDelete = Set<String>()

        for remote in remoteRecords.values {
            let previous = state.entities[remote.key]
            let local = localSnapshots[remote.key]

            guard let local else {
                if previous == nil {
                    remoteToApply.append(remote)
                }
                continue
            }

            guard remote.payloadHash != local.payloadHash else {
                state.entities[remote.key] = CloudSyncStoredEntity(
                    payloadHash: local.payloadHash,
                    clientUpdatedAt: max(local.clientUpdatedAt, remote.clientUpdatedAt),
                    knownRemote: true
                )
                continue
            }

            let localChanged = previous.map { $0.payloadHash != local.payloadHash } ?? true
            let remoteChanged = previous.map { $0.payloadHash != remote.payloadHash } ?? true

            if !localChanged || (remoteChanged && remote.clientUpdatedAt > local.clientUpdatedAt) {
                remoteToApply.append(remote)
            }
        }

        for (key, previous) in state.entities where previous.knownRemote && remoteRecords[key] == nil {
            guard let local = localSnapshots[key] else {
                state.entities.removeValue(forKey: key)
                continue
            }
            let localChanged = previous.payloadHash != local.payloadHash
            if !localChanged {
                localKeysToDelete.insert(key)
            }
        }

        if !localKeysToDelete.isEmpty {
            try deleteLocal(keys: localKeysToDelete, context: context)
            for key in localKeysToDelete {
                state.entities.removeValue(forKey: key)
            }
        }

        guard !remoteToApply.isEmpty else { return }
        try upsertRemote(records: remoteToApply, state: &state, context: context)
        try context.save()
    }

    private func pushLocalChanges(
        localSnapshots: [String: LocalCloudSnapshot],
        remoteRecords: [String: RemoteCloudRecord],
        priorState: CloudSyncStoredState
    ) async throws {
        var recordsToSave: [CKRecord] = []
        var tempAssetURLs: [URL] = []

        for snapshot in localSnapshots.values {
            guard remoteRecords[snapshot.key]?.payloadHash != snapshot.payloadHash else { continue }
            let (record, tempURL) = try makeRecord(from: snapshot, existing: remoteRecords[snapshot.key]?.record)
            recordsToSave.append(record)
            if let tempURL { tempAssetURLs.append(tempURL) }
        }

        var recordIDsToDelete: [CKRecord.ID] = []
        for (key, previous) in priorState.entities where previous.knownRemote && localSnapshots[key] == nil {
            if let remote = remoteRecords[key] {
                recordIDsToDelete.append(remote.record.recordID)
            } else if let parsed = CloudSyncEntityKind.parse(key: key) {
                recordIDsToDelete.append(CKRecord.ID(recordName: parsed.kind.recordName(for: parsed.id)))
            }
        }

        defer {
            for url in tempAssetURLs {
                try? FileManager.default.removeItem(at: url)
            }
        }

        try await modifyCloud(recordsToSave: recordsToSave, recordIDsToDelete: recordIDsToDelete)
    }

    private func modifyCloud(recordsToSave: [CKRecord], recordIDsToDelete: [CKRecord.ID]) async throws {
        guard !recordsToSave.isEmpty || !recordIDsToDelete.isEmpty else { return }

        let saveChunks = recordsToSave.chunked(into: 100)
        let deleteChunks = recordIDsToDelete.chunked(into: 100)
        let maxChunkCount = max(saveChunks.count, deleteChunks.count)

        var totalFailures = 0

        for index in 0..<maxChunkCount {
            let saveChunk = index < saveChunks.count ? saveChunks[index] : []
            let deleteChunk = index < deleteChunks.count ? deleteChunks[index] : []

            let result = try await retryCloudKit {
                try await self.database.modifyRecords(
                    saving: saveChunk,
                    deleting: deleteChunk,
                    savePolicy: .allKeys,
                    atomically: false
                )
            }

            for (recordID, saveResult) in result.saveResults {
                if case .failure(let error) = saveResult {
                    totalFailures += 1
                    logSyncError("[CloudSync] 保存失败 \(recordID.recordName): \(error.localizedDescription)")
                }
            }
            for (recordID, deleteResult) in result.deleteResults {
                if case .failure(let error) = deleteResult {
                    totalFailures += 1
                    logSyncError("[CloudSync] 删除失败 \(recordID.recordName): \(error.localizedDescription)")
                }
            }
        }

        if totalFailures > 0 {
            logSyncError("[CloudSync] 本次同步共有 \(totalFailures) 条记录操作失败，已跳过")
        }
    }
}

// MARK: - Local snapshots

private extension CloudSyncService {
    func makeLocalSnapshots(
        context: ModelContext,
        state: CloudSyncStoredState,
        now: Date
    ) throws -> [String: LocalCloudSnapshot] {
        var snapshots: [String: LocalCloudSnapshot] = [:]
        let encoder = Self.makeEncoder()

        let beans = try context.fetch(FetchDescriptor<Bean>())
        for bean in beans {
            let payload = CloudBeanPayload(bean: bean)
            let data = try encoder.encode(payload)
            let snapshot = makeSnapshot(
                kind: .bean,
                id: payload.id,
                payloadData: data,
                assetData: bean.coverImageData,
                state: state,
                now: now
            )
            snapshots[snapshot.key] = snapshot
        }

        let brews = try context.fetch(FetchDescriptor<Brew>())
        for brew in brews {
            guard let payload = CloudBrewPayload(brew: brew) else { continue }
            let data = try encoder.encode(payload)
            let snapshot = makeSnapshot(
                kind: .brew,
                id: payload.id,
                payloadData: data,
                assetData: nil,
                state: state,
                now: now
            )
            snapshots[snapshot.key] = snapshot
        }

        let recipes = try context.fetch(FetchDescriptor<RecipeArchive>())
        for recipe in recipes {
            let payload = CloudRecipePayload(recipe: recipe)
            let data = try encoder.encode(payload)
            let snapshot = makeSnapshot(
                kind: .recipe,
                id: payload.id,
                payloadData: data,
                assetData: nil,
                state: state,
                now: now
            )
            snapshots[snapshot.key] = snapshot
        }

        return snapshots
    }

    func makeSnapshot(
        kind: CloudSyncEntityKind,
        id: UUID,
        payloadData: Data,
        assetData: Data?,
        state: CloudSyncStoredState,
        now: Date
    ) -> LocalCloudSnapshot {
        let payloadHash = Self.sha256Hex(payloadData)
        let key = kind.key(for: id)
        let previous = state.entities[key]
        let clientUpdatedAt = previous?.payloadHash == payloadHash
            ? previous?.clientUpdatedAt ?? now
            : now

        return LocalCloudSnapshot(
            key: key,
            kind: kind,
            id: id,
            payloadData: payloadData,
            payloadHash: payloadHash,
            assetData: assetData,
            clientUpdatedAt: clientUpdatedAt
        )
    }
}

// MARK: - Cloud record mapping

private extension CloudSyncService {
    func makeRecord(from snapshot: LocalCloudSnapshot, existing: CKRecord?) throws -> (CKRecord, URL?) {
        let record = existing ?? CKRecord(
            recordType: snapshot.kind.recordType,
            recordID: CKRecord.ID(recordName: snapshot.kind.recordName(for: snapshot.id))
        )
        record[CloudRecordField.entityID] = snapshot.id.uuidString as NSString
        record[CloudRecordField.payload] = snapshot.payloadData as NSData
        record[CloudRecordField.payloadHash] = snapshot.payloadHash as NSString
        record[CloudRecordField.clientUpdatedAt] = snapshot.clientUpdatedAt as NSDate
        record[CloudRecordField.schemaVersion] = NSNumber(value: 1)

        guard snapshot.kind == .bean else { return (record, nil) }

        if let assetData = snapshot.assetData {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("CoffeeStoryCloudSync-\(snapshot.id.uuidString)-\(UUID().uuidString).jpg")
            try assetData.write(to: url, options: .atomic)
            record[CloudRecordField.coverImage] = CKAsset(fileURL: url)
            return (record, url)
        } else {
            record[CloudRecordField.coverImage] = nil
            return (record, nil)
        }
    }
}

// MARK: - SwiftData merge

private extension CloudSyncService {
    func upsertRemote(
        records: [RemoteCloudRecord],
        state: inout CloudSyncStoredState,
        context: ModelContext
    ) throws {
        let decoder = Self.makeDecoder()
        var beans = try context.fetch(FetchDescriptor<Bean>())
        var beanByID = Dictionary(uniqueKeysWithValues: beans.map { ($0.id, $0) })

        for remote in records.filter({ $0.kind == .bean }) {
            let payload = try decoder.decode(CloudBeanPayload.self, from: remote.payloadData)
            let bean = beanByID[payload.id] ?? Bean()
            apply(payload, assetData: remote.assetData, to: bean)
            if beanByID[payload.id] == nil {
                context.insert(bean)
                beanByID[payload.id] = bean
            }
            state.entities[remote.key] = CloudSyncStoredEntity(
                payloadHash: remote.payloadHash,
                clientUpdatedAt: remote.clientUpdatedAt,
                knownRemote: true
            )
        }

        for remote in records.filter({ $0.kind == .recipe }) {
            let payload = try decoder.decode(CloudRecipePayload.self, from: remote.payloadData)
            let existing = try fetchRecipe(id: payload.id, context: context)
            let recipe = existing ?? RecipeArchive()
            apply(payload, to: recipe)
            if existing == nil {
                context.insert(recipe)
            }
            state.entities[remote.key] = CloudSyncStoredEntity(
                payloadHash: remote.payloadHash,
                clientUpdatedAt: remote.clientUpdatedAt,
                knownRemote: true
            )
        }

        beans = try context.fetch(FetchDescriptor<Bean>())
        beanByID = Dictionary(uniqueKeysWithValues: beans.map { ($0.id, $0) })
        for remote in records.filter({ $0.kind == .brew }) {
            let payload = try decoder.decode(CloudBrewPayload.self, from: remote.payloadData)
            guard let bean = beanByID[payload.beanID] else { continue }
            let existing = try fetchBrew(id: payload.id, context: context)
            let brew = existing ?? Brew()
            apply(payload, bean: bean, to: brew)
            if existing == nil {
                context.insert(brew)
            }
            state.entities[remote.key] = CloudSyncStoredEntity(
                payloadHash: remote.payloadHash,
                clientUpdatedAt: remote.clientUpdatedAt,
                knownRemote: true
            )
        }
    }

    func deleteLocal(keys: Set<String>, context: ModelContext) throws {
        let brews = try context.fetch(FetchDescriptor<Brew>())
        for brew in brews where keys.contains(CloudSyncEntityKind.brew.key(for: brew.id)) {
            context.delete(brew)
        }

        let recipes = try context.fetch(FetchDescriptor<RecipeArchive>())
        for recipe in recipes where keys.contains(CloudSyncEntityKind.recipe.key(for: recipe.id)) {
            context.delete(recipe)
        }

        let beans = try context.fetch(FetchDescriptor<Bean>())
        for bean in beans where keys.contains(CloudSyncEntityKind.bean.key(for: bean.id)) {
            context.delete(bean)
        }

        try context.save()
    }

    func fetchBrew(id: UUID, context: ModelContext) throws -> Brew? {
        let descriptor = FetchDescriptor<Brew>(predicate: #Predicate { $0.id == id })
        return try context.fetch(descriptor).first
    }

    func fetchRecipe(id: UUID, context: ModelContext) throws -> RecipeArchive? {
        let descriptor = FetchDescriptor<RecipeArchive>(predicate: #Predicate { $0.id == id })
        return try context.fetch(descriptor).first
    }

    func apply(_ payload: CloudBeanPayload, assetData: Data?, to bean: Bean) {
        bean.id = payload.id
        bean.name = payload.name
        bean.roaster = payload.roaster
        bean.originText = payload.originText
        bean.process = Process(rawValue: payload.processRaw) ?? .other
        bean.roastLevel = RoastLevel(rawValue: payload.roastLevelRaw) ?? .medium
        bean.roastDate = payload.roastDate
        bean.bagWeightGrams = payload.bagWeightGrams
        bean.remainingGrams = payload.remainingGrams
        bean.flavorTags = payload.flavorTags
        bean.coverImageData = payload.coverImageHash == nil ? nil : assetData
        bean.notes = payload.notes
        bean.grinderNote = payload.grinderNote
        bean.createdAt = payload.createdAt
        bean.archived = payload.archived
        bean.archivedAt = payload.archivedAt
    }

    func apply(_ payload: CloudBrewPayload, bean: Bean, to brew: Brew) {
        brew.id = payload.id
        brew.createdAt = payload.createdAt
        brew.grind = payload.grind
        brew.dose = payload.dose
        brew.water = payload.water
        brew.temp = payload.temp
        brew.totalTime = payload.totalTime
        brew.pours = payload.pours
        brew.acidity = payload.acidity
        brew.sweetness = payload.sweetness
        brew.bodyScore = payload.bodyScore
        brew.aftertaste = payload.aftertaste
        brew.balance = payload.balance
        brew.overall = payload.overall
        brew.takeaway = payload.takeaway
        brew.nextTweaks = payload.nextTweaks
        brew.nextTweakNote = payload.nextTweakNote
        if payload.isBest {
            for other in bean.brews where other.id != payload.id {
                other.isBest = false
            }
        }
        brew.isBest = payload.isBest
        brew.bean = bean
    }

    func apply(_ payload: CloudRecipePayload, to recipe: RecipeArchive) {
        recipe.id = payload.id
        recipe.createdAt = payload.createdAt
        recipe.sourceBeanName = payload.sourceBeanName
        recipe.originText = payload.originText
        recipe.processRaw = payload.processRaw
        recipe.roastLevelRaw = payload.roastLevelRaw
        recipe.flavorTags = payload.flavorTags
        recipe.grind = payload.grind
        recipe.dose = payload.dose
        recipe.water = payload.water
        recipe.temp = payload.temp
        recipe.totalTime = payload.totalTime
        recipe.pours = payload.pours
        recipe.overall = payload.overall
        recipe.takeaway = payload.takeaway
    }
}

// MARK: - Payloads

private struct CloudBeanPayload: Codable {
    var id: UUID
    var name: String
    var roaster: String
    var originText: String
    var processRaw: String
    var roastLevelRaw: String
    var roastDate: Date?
    var bagWeightGrams: Double
    var remainingGrams: Double
    var flavorTags: [String]
    var coverImageHash: String?
    var notes: String
    var grinderNote: String
    var createdAt: Date
    var archived: Bool
    var archivedAt: Date?

    init(bean: Bean) {
        id = bean.id
        name = bean.name
        roaster = bean.roaster
        originText = bean.originText
        processRaw = bean.process.rawValue
        roastLevelRaw = bean.roastLevel.rawValue
        roastDate = bean.roastDate
        bagWeightGrams = bean.bagWeightGrams
        remainingGrams = bean.remainingGrams
        flavorTags = bean.flavorTags
        coverImageHash = bean.coverImageData.map(CloudSyncService.sha256Hex)
        notes = bean.notes
        grinderNote = bean.grinderNote
        createdAt = bean.createdAt
        archived = bean.archived
        archivedAt = bean.archivedAt
    }
}

private struct CloudBrewPayload: Codable {
    var id: UUID
    var beanID: UUID
    var createdAt: Date
    var grind: Double
    var dose: Double
    var water: Double
    var temp: Double?
    var totalTime: TimeInterval
    var pours: [PourStage]
    var acidity: Double?
    var sweetness: Double?
    var bodyScore: Double?
    var aftertaste: Double?
    var balance: Double?
    var overall: Double?
    var takeaway: String
    var nextTweaks: [NextTweak]
    var nextTweakNote: String
    var isBest: Bool

    init?(brew: Brew) {
        guard let beanID = brew.bean?.id else { return nil }
        id = brew.id
        self.beanID = beanID
        createdAt = brew.createdAt
        grind = brew.grind
        dose = brew.dose
        water = brew.water
        temp = brew.temp
        totalTime = brew.totalTime
        pours = brew.pours
        acidity = brew.acidity
        sweetness = brew.sweetness
        bodyScore = brew.bodyScore
        aftertaste = brew.aftertaste
        balance = brew.balance
        overall = brew.overall
        takeaway = brew.takeaway
        nextTweaks = brew.nextTweaks
        nextTweakNote = brew.nextTweakNote
        isBest = brew.isBest
    }
}

private struct CloudRecipePayload: Codable {
    var id: UUID
    var createdAt: Date
    var sourceBeanName: String
    var originText: String
    var processRaw: String
    var roastLevelRaw: String
    var flavorTags: [String]
    var grind: Double
    var dose: Double
    var water: Double
    var temp: Double?
    var totalTime: TimeInterval
    var pours: [PourStage]
    var overall: Double?
    var takeaway: String

    init(recipe: RecipeArchive) {
        id = recipe.id
        createdAt = recipe.createdAt
        sourceBeanName = recipe.sourceBeanName
        originText = recipe.originText
        processRaw = recipe.processRaw
        roastLevelRaw = recipe.roastLevelRaw
        flavorTags = recipe.flavorTags
        grind = recipe.grind
        dose = recipe.dose
        water = recipe.water
        temp = recipe.temp
        totalTime = recipe.totalTime
        pours = recipe.pours
        overall = recipe.overall
        takeaway = recipe.takeaway
    }
}

// MARK: - Support types

private struct LocalCloudSnapshot {
    var key: String
    var kind: CloudSyncEntityKind
    var id: UUID
    var payloadData: Data
    var payloadHash: String
    var assetData: Data?
    var clientUpdatedAt: Date
}

private struct RemoteCloudRecord {
    var key: String
    var kind: CloudSyncEntityKind
    var id: UUID
    var record: CKRecord
    var payloadData: Data
    var payloadHash: String
    var assetData: Data?
    var clientUpdatedAt: Date

    init?(kind: CloudSyncEntityKind, record: CKRecord) {
        guard let idString = record[CloudRecordField.entityID] as? String,
              let id = UUID(uuidString: idString),
              let payloadData = record[CloudRecordField.payload] as? Data
        else { return nil }

        self.key = kind.key(for: id)
        self.kind = kind
        self.id = id
        self.record = record
        self.payloadData = payloadData
        self.payloadHash = (record[CloudRecordField.payloadHash] as? String)
            ?? CloudSyncService.sha256Hex(payloadData)
        self.clientUpdatedAt = (record[CloudRecordField.clientUpdatedAt] as? Date)
            ?? record.modificationDate
            ?? Date.distantPast

        if let asset = record[CloudRecordField.coverImage] as? CKAsset,
           let url = asset.fileURL {
            self.assetData = try? Data(contentsOf: url)
        } else {
            self.assetData = nil
        }
    }
}

private enum CloudSyncEntityKind: String, CaseIterable, Codable {
    case bean = "CSBean"
    case brew = "CSBrew"
    case recipe = "CSRecipe"

    var recordType: CKRecord.RecordType { rawValue }

    var prefix: String {
        switch self {
        case .bean: "bean"
        case .brew: "brew"
        case .recipe: "recipe"
        }
    }

    func key(for id: UUID) -> String {
        "\(rawValue):\(id.uuidString)"
    }

    func recordName(for id: UUID) -> String {
        "\(prefix)-\(id.uuidString)"
    }

    static func parse(key: String) -> (kind: CloudSyncEntityKind, id: UUID)? {
        let parts = key.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2,
              let kind = CloudSyncEntityKind(rawValue: parts[0]),
              let id = UUID(uuidString: parts[1])
        else { return nil }
        return (kind, id)
    }
}

private enum CloudRecordField {
    static let entityID = "entityID"
    static let payload = "payload"
    static let payloadHash = "payloadHash"
    static let clientUpdatedAt = "clientUpdatedAt"
    static let schemaVersion = "schemaVersion"
    static let coverImage = "coverImage"
}

private struct CloudSyncStoredState: Codable {
    var lastSyncedAt: Date?
    var iCloudUserRecordName: String?
    var entities: [String: CloudSyncStoredEntity]

    init(
        lastSyncedAt: Date? = nil,
        iCloudUserRecordName: String? = nil,
        entities: [String: CloudSyncStoredEntity] = [:]
    ) {
        self.lastSyncedAt = lastSyncedAt
        self.iCloudUserRecordName = iCloudUserRecordName
        self.entities = entities
    }
}

private struct CloudSyncStoredEntity: Codable {
    var payloadHash: String
    var clientUpdatedAt: Date
    var knownRemote: Bool
}

private final class CloudSyncStateStore {
    private let key = "cloudSync.state.v1"

    func load() -> CloudSyncStoredState {
        guard let data = UserDefaults.standard.data(forKey: key),
              let state = try? JSONDecoder().decode(CloudSyncStoredState.self, from: data)
        else { return CloudSyncStoredState() }
        return state
    }

    func save(_ state: CloudSyncStoredState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

private enum CloudSyncError: LocalizedError {
    case iCloudUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .iCloudUnavailable(let message): message
        }
    }
}

private extension CKAccountStatus {
    var message: String {
        switch self {
        case .available:
            "iCloud 可用"
        case .noAccount:
            "未登录 iCloud"
        case .restricted:
            "当前 iCloud 账号受限"
        case .couldNotDetermine:
            "无法确认 iCloud 状态"
        case .temporarilyUnavailable:
            "iCloud 暂时不可用"
        @unknown default:
            "iCloud 状态未知"
        }
    }
}

private extension CloudSyncService {
    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    nonisolated static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0, !isEmpty else { return [] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
