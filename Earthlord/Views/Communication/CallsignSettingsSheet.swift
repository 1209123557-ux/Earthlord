import SwiftUI
import Supabase

struct CallsignSettingsSheet: View {
    @ObservedObject private var authManager = AuthManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var callsign = ""
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var saveError: String? = nil
    @State private var saveSuccess = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // 说明
                VStack(spacing: 8) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 40))
                        .foregroundColor(ApocalypseTheme.primary)
                    Text("设置呼号")
                        .font(.title3).fontWeight(.bold)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                    Text("呼号是你在频道中显示的通讯标识，其他幸存者将通过呼号识别你")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 8)

                // 输入框
                VStack(alignment: .leading, spacing: 6) {
                    Text("呼号")
                        .font(.caption).fontWeight(.semibold)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                    TextField("例如：ALPHA-01、幸存者-北京", text: $callsign)
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .tint(ApocalypseTheme.primary)
                        .padding(12)
                        .background(ApocalypseTheme.background)
                        .cornerRadius(10)
                        .autocorrectionDisabled()
                }

                if let error = saveError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.danger)
                }

                if saveSuccess {
                    Label("呼号已保存", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.success)
                }

                // 保存按钮
                Button(action: saveCallsign) {
                    Group {
                        if isSaving {
                            ProgressView().tint(.white)
                        } else {
                            Text("保存呼号")
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(callsign.trimmingCharacters(in: .whitespaces).isEmpty
                                ? ApocalypseTheme.textSecondary
                                : ApocalypseTheme.primary)
                    .cornerRadius(12)
                }
                .disabled(callsign.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)

                Spacer()
            }
            .padding(20)
            .background(ApocalypseTheme.background.ignoresSafeArea())
            .navigationTitle("呼号设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
            .onAppear { loadCallsign() }
        }
    }

    // MARK: - 加载当前呼号

    private func loadCallsign() {
        guard let userId = authManager.currentUser?.id else { return }
        isLoading = true
        Task {
            do {
                struct ProfileRow: Decodable { let callsign: String? }
                let rows: [ProfileRow] = try await supabase
                    .from("user_profiles")
                    .select("callsign")
                    .eq("user_id", value: userId.uuidString)
                    .limit(1)
                    .execute()
                    .value
                if let row = rows.first, let cs = row.callsign {
                    callsign = cs
                }
            } catch {
                // 无记录时静默处理
            }
            isLoading = false
        }
    }

    // MARK: - 保存呼号

    private func saveCallsign() {
        guard let userId = authManager.currentUser?.id else { return }
        let trimmed = callsign.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        isSaving = true
        saveError = nil
        saveSuccess = false

        Task {
            do {
                struct UpsertPayload: Encodable {
                    let user_id: String
                    let callsign: String
                    let updated_at: String
                }
                let payload = UpsertPayload(
                    user_id: userId.uuidString,
                    callsign: trimmed,
                    updated_at: ISO8601DateFormatter().string(from: Date())
                )
                try await supabase
                    .from("user_profiles")
                    .upsert(payload, onConflict: "user_id")
                    .execute()
                saveSuccess = true
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
            } catch {
                saveError = "保存失败: \(error.localizedDescription)"
            }
            isSaving = false
        }
    }
}
