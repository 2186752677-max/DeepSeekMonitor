import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    @State private var apiKeyInput: String = ""
    @State private var showAPIKey: Bool = false
    @State private var selectedInterval: RefreshInterval = .fiveMinutes
    @State private var testResult: String?
    @State private var isTesting: Bool = false

    // MARK: - Refresh Interval Options

    enum RefreshInterval: TimeInterval, CaseIterable {
        case oneMinute = 60
        case fiveMinutes = 300
        case tenMinutes = 600
        case thirtyMinutes = 1800
        case oneHour = 3600

        var label: String {
            switch self {
            case .oneMinute:    return "1 分钟"
            case .fiveMinutes:  return "5 分钟"
            case .tenMinutes:   return "10 分钟"
            case .thirtyMinutes: return "30 分钟"
            case .oneHour:      return "1 小时"
            }
        }
    }

    // MARK: - Body

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("通用", systemImage: "gear")
                }

            aboutTab
                .tabItem {
                    Label("关于", systemImage: "info.circle")
                }
        }
        .onAppear {
            apiKeyInput = appState.apiKey
            if let match = RefreshInterval.allCases.first(where: {
                abs($0.rawValue - appState.refreshInterval) < 1
            }) {
                selectedInterval = match
            }
        }
    }

    // MARK: - General Tab

    private var generalTab: some View {
        ScrollView {
            Form {
                apiKeySection
                refreshSection
            }
            .formStyle(.grouped)
            .padding(.top, 8)
        }
    }

    // MARK: API Key Section

    private var apiKeySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    if showAPIKey {
                        TextField("sk-...", text: $apiKeyInput)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    } else {
                        SecureField("sk-...", text: $apiKeyInput)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    }

                    Button {
                        showAPIKey.toggle()
                    } label: {
                        Image(systemName: showAPIKey ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)
                    .help(showAPIKey ? "隐藏 API Key" : "显示 API Key")
                }

                HStack(spacing: 8) {
                    Button("保存") {
                        appState.saveAPIKey(apiKeyInput)
                        testResult = nil
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button("测试连接") {
                        Task { await testConnection() }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .disabled(isTesting)

                    if isTesting {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 14, height: 14)
                    }
                }

                // Test result
                if let result = testResult {
                    HStack(spacing: 6) {
                        let success = result.hasPrefix("✓")
                        Image(systemName: success
                            ? "checkmark.circle.fill"
                            : "xmark.circle.fill")
                            .foregroundColor(success ? .green : .red)
                            .font(.system(size: 12))
                        Text(result.replacingOccurrences(of: "✓ ", with: "")
                                    .replacingOccurrences(of: "✗ ", with: ""))
                            .font(.system(size: 11))
                            .foregroundColor(success ? .green : .red)
                            .lineLimit(2)
                    }
                    .transition(.opacity)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("API Key").font(.system(size: 11, weight: .semibold))
        } footer: {
            Text("在 platform.deepseek.com → API Keys 获取你的 Key")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }

    // MARK: Refresh Section

    private var refreshSection: some View {
        Section {
            Picker("自动刷新间隔", selection: $selectedInterval) {
                ForEach(RefreshInterval.allCases, id: \.self) { interval in
                    Text(interval.label).tag(interval)
                }
            }
            .pickerStyle(.radioGroup)
            .onChange(of: selectedInterval) { newValue in
                appState.saveRefreshInterval(newValue.rawValue)
            }

            if appState.balanceInfo != nil, let lastRefresh = appState.lastRefresh {
                HStack {
                    Text("上次刷新")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatDateTime(lastRefresh))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text("刷新设置").font(.system(size: 11, weight: .semibold))
        }
    }

    // MARK: - About Tab

    private var aboutTab: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text("DeepSeek Monitor")
                .font(.title2)
                .fontWeight(.semibold)

            Text("版本 1.0.0")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("实时监控你的 DeepSeek API 用量和余额")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(spacing: 8) {
                Link(destination: URL(string: "https://platform.deepseek.com")!) {
                    Label("DeepSeek 平台", systemImage: "link")
                        .font(.system(size: 12))
                }

                Link(destination: URL(string: "https://api-docs.deepseek.com")!) {
                    Label("API 文档", systemImage: "doc.text")
                        .font(.system(size: 12))
                }
            }
            .padding(.top, 4)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    // MARK: - Actions

    private func testConnection() async {
        isTesting = true
        testResult = nil

        let key = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            testResult = "✗ 请先输入 API Key"
            isTesting = false
            return
        }

        do {
            let balance = try await DeepSeekAPI.fetchBalance(apiKey: key)
            if balance.primaryBalance != nil {
                testResult = "✓ 连接成功，余额: \(balance.formattedFull)"
            } else {
                testResult = "✓ 连接成功 (未获取到余额数据)"
            }
        } catch {
            testResult = "✗ \(error.localizedDescription)"
        }

        isTesting = false
    }

    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
}
