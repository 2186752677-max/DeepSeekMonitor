import Foundation

// MARK: - Response Models

struct BalanceInfo: Codable {
    let isAvailable: Bool
    let balanceInfos: [BalanceItem]

    enum CodingKeys: String, CodingKey {
        case isAvailable = "is_available"
        case balanceInfos = "balance_infos"
    }

    var primaryBalance: BalanceItem? {
        balanceInfos.first
    }

    /// Compact version for menu bar display (no thousand separators)
    var formattedCompact: String {
        guard let b = primaryBalance, let total = Double(b.totalBalance) else {
            return "--"
        }
        return CurrencyFormatter.compact(total, currency: b.currency)
    }

    /// Full version for detail view (with thousand separators)
    var formattedFull: String {
        guard let b = primaryBalance, let total = Double(b.totalBalance) else {
            return "--"
        }
        return CurrencyFormatter.full(total, currency: b.currency)
    }

    var totalBalanceDouble: Double? {
        guard let b = primaryBalance else { return nil }
        return Double(b.totalBalance)
    }
}

struct BalanceItem: Codable {
    let currency: String
    let totalBalance: String
    let toppedUpBalance: String
    let grantedBalance: String

    enum CodingKeys: String, CodingKey {
        case currency
        case totalBalance = "total_balance"
        case toppedUpBalance = "topped_up_balance"
        case grantedBalance = "granted_balance"
    }
}

// MARK: - Currency Formatting

enum CurrencyFormatter {
    /// Compact: no thousand separators — for menu bar
    static func compact(_ value: Double, currency: String) -> String {
        let symbol = currencySymbol(currency)
        if value >= 10_000 {
            return String(format: "%@%.1f万", symbol, value / 10_000)
        }
        return String(format: "%@%.2f", symbol, value)
    }

    /// Full: with thousand separators — for detail view
    static func full(_ value: Double, currency: String) -> String {
        let symbol = currencySymbol(currency)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let num = formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
        return "\(symbol)\(num)"
    }

    static func currencySymbol(_ currency: String) -> String {
        switch currency.uppercased() {
        case "CNY": return "¥"
        case "USD": return "$"
        case "EUR": return "€"
        case "GBP": return "£"
        case "JPY": return "¥"
        default: return currency
        }
    }
}

// MARK: - API Client

enum DeepSeekAPI {
    static let baseURL = "https://api.deepseek.com"

    static func fetchBalance(apiKey: String) async throws -> BalanceInfo {
        guard !apiKey.isEmpty else {
            throw APIError.noAPIKey
        }

        guard let url = URL(string: "\(baseURL)/user/balance") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 401:
            throw APIError.invalidAPIKey
        case 403:
            throw APIError.accessDenied
        case 429:
            throw APIError.rateLimited
        default:
            throw APIError.httpError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        do {
            let balanceInfo = try decoder.decode(BalanceInfo.self, from: data)
            return balanceInfo
        } catch {
            throw APIError.decodingError(error)
        }
    }
}

// MARK: - API Errors

enum APIError: LocalizedError {
    case noAPIKey
    case invalidURL
    case invalidResponse
    case invalidAPIKey
    case accessDenied
    case rateLimited
    case httpError(Int)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "请先设置 API Key"
        case .invalidURL:
            return "无效的 URL"
        case .invalidResponse:
            return "无效的服务器响应"
        case .invalidAPIKey:
            return "API Key 无效，请检查后重试"
        case .accessDenied:
            return "访问被拒绝，请检查 API Key 权限"
        case .rateLimited:
            return "请求过于频繁，请稍后重试"
        case .httpError(let code):
            return "服务器错误 (HTTP \(code))"
        case .decodingError:
            return "数据解析失败"
        }
    }
}
