import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {

    // MARK: - Published State

    @Published var balanceInfo: BalanceInfo?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastRefresh: Date?
    @Published var apiKey: String = ""
    @Published var refreshInterval: TimeInterval = 300
    @Published var initialBalance: Double?

    // MARK: - Private

    private var timer: Timer?
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let apiKey = "deepseek_api_key"
        static let refreshInterval = "refresh_interval"
        static let initialBalance = "deepseek_initial_balance"
    }

    // MARK: - Computed

    var hasAPIKey: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var totalConsumed: Double? {
        guard let initial = initialBalance,
              let current = balanceInfo?.totalBalanceDouble else { return nil }
        let delta = initial - current
        return max(0, delta)
    }

    var formattedConsumed: String {
        guard let consumed = totalConsumed else { return "--" }
        guard let currency = balanceInfo?.primaryBalance?.currency else {
            return CurrencyFormatter.full(consumed, currency: "CNY")
        }
        return CurrencyFormatter.full(consumed, currency: currency)
    }

    // MARK: - Init

    init() {
        loadSettings()
        if hasAPIKey {
            Task { await refresh() }
        }
        startTimer()
    }

    deinit {
        timer?.invalidate()
    }

    // MARK: - Public Methods

    func refresh() async {
        guard hasAPIKey else { return }

        isLoading = true
        errorMessage = nil

        do {
            let balance = try await DeepSeekAPI.fetchBalance(apiKey: apiKey)
            balanceInfo = balance
            lastRefresh = Date()
            errorMessage = nil

            if initialBalance == nil {
                initialBalance = balance.totalBalanceDouble
                saveInitialBalance()
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func saveAPIKey(_ key: String) {
        apiKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        defaults.set(apiKey, forKey: Keys.apiKey)

        // Reset state for new key
        balanceInfo = nil
        initialBalance = nil
        errorMessage = nil
        lastRefresh = nil
        defaults.removeObject(forKey: Keys.initialBalance)

        if hasAPIKey {
            Task { await refresh() }
        }
    }

    func saveRefreshInterval(_ interval: TimeInterval) {
        refreshInterval = interval
        defaults.set(interval, forKey: Keys.refreshInterval)
        restartTimer()
    }

    // MARK: - Private

    private func loadSettings() {
        apiKey = defaults.string(forKey: Keys.apiKey) ?? ""
        let saved = defaults.double(forKey: Keys.refreshInterval)
        refreshInterval = saved > 0 ? saved : 300
        initialBalance = defaults.object(forKey: Keys.initialBalance) as? Double
    }

    private func saveInitialBalance() {
        guard let balance = initialBalance else { return }
        defaults.set(balance, forKey: Keys.initialBalance)
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refresh()
            }
        }
        // Allow timer in menu bar app runloop
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func restartTimer() {
        timer?.invalidate()
        startTimer()
    }
}
