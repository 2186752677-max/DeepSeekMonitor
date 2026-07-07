import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            headerView
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 6)

            Divider()

            // Content
            Group {
                if !appState.hasAPIKey {
                    noKeyView
                } else if let error = appState.errorMessage, appState.balanceInfo == nil {
                    errorView(error)
                } else if let balance = appState.balanceInfo {
                    balanceDetailView(balance)
                } else if appState.isLoading {
                    loadingView
                }
            }
            .padding(.horizontal, 12)

            Divider()

            // Footer actions
            footerView
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .frame(minWidth: 280)
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack(spacing: 6) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.accentColor)
            Text("DeepSeek 用量监控")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
        }
    }

    private var loadingView: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
            Text("获取余额中...")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 20)
    }

    private var noKeyView: some View {
        VStack(spacing: 10) {
            Image(systemName: "key.fill")
                .font(.system(size: 28))
                .foregroundColor(.secondary)
                .padding(.top, 8)
            Text("未设置 API Key")
                .font(.system(size: 13, weight: .medium))
            Text("请在设置中输入你的\nDeepSeek API Key")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            Button("打开设置...") {
                showSettings()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .padding(.top, 2)
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28))
                .foregroundColor(.orange)
                .padding(.top, 8)
            Text("获取失败")
                .font(.system(size: 13, weight: .medium))
            Text(error)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            Button("重试") {
                Task { await appState.refresh() }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .padding(.top, 2)
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    private func balanceDetailView(_ balance: BalanceInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // 总余额
            HStack(alignment: .firstTextBaseline) {
                Text("当前余额")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Spacer()
                Text(balance.formattedFull)
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
            }
            .padding(.top, 6)

            // 余额明细
            if let info = balance.primaryBalance {
                VStack(alignment: .leading, spacing: 4) {
                    balanceRow(
                        label: "充值余额",
                        value: Double(info.toppedUpBalance),
                        currency: info.currency
                    )
                    balanceRow(
                        label: "赠送余额",
                        value: Double(info.grantedBalance),
                        currency: info.currency
                    )
                }
                .padding(.leading, 2)
            }

            // 消耗统计
            if appState.totalConsumed != nil {
                Divider()
                    .padding(.vertical, 2)

                HStack {
                    Text("本次会话消耗")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("-\(appState.formattedConsumed)")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.orange)
                }
            }

            // 最后刷新时间
            refreshStatus
                .padding(.top, 2)
                .padding(.bottom, 4)
        }
    }

    private func balanceRow(label: String, value: Double?, currency: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Spacer()
            Text(value.map { CurrencyFormatter.full($0, currency: currency) } ?? "--")
                .font(.system(size: 12, design: .monospaced))
        }
    }

    private var refreshStatus: some View {
        HStack(spacing: 4) {
            Spacer()
            if appState.isLoading {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 10, height: 10)
                Text("刷新中...")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            } else if let lastRefresh = appState.lastRefresh {
                Circle()
                    .fill(Color.green)
                    .frame(width: 5, height: 5)
                Text("更新于 \(formatTime(lastRefresh))")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack(spacing: 4) {
            Button {
                Task { await appState.refresh() }
            } label: {
                Label("刷新", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderless)
            .disabled(appState.isLoading || !appState.hasAPIKey)
            .font(.system(size: 12))

            Divider()
                .frame(height: 16)

            Button {
                showSettings()
            } label: {
                Label("设置", systemImage: "gear")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderless)
            .font(.system(size: 12))

            Divider()
                .frame(height: 16)

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("退出", systemImage: "power")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderless)
            .font(.system(size: 12))
        }
    }

    // MARK: - Helpers

    private func showSettings() {
        openWindow(id: "settings")
        // Brief delay then bring window to front
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}
