import Foundation

public struct DeepSeekBalanceResponse: Codable, Equatable, Sendable {
    public let isAvailable: Bool
    public let balanceInfos: [DeepSeekBalanceInfo]

    public init(isAvailable: Bool, balanceInfos: [DeepSeekBalanceInfo]) {
        self.isAvailable = isAvailable
        self.balanceInfos = balanceInfos
    }

    public var preferredInfo: DeepSeekBalanceInfo? {
        info(preferredCurrency: "CNY")
    }

    public func info(preferredCurrency: String) -> DeepSeekBalanceInfo? {
        balanceInfos.first {
            $0.currency.caseInsensitiveCompare(preferredCurrency) == .orderedSame
        } ?? balanceInfos.first
    }

    private enum CodingKeys: String, CodingKey {
        case isAvailable = "is_available"
        case balanceInfos = "balance_infos"
    }
}

public struct DeepSeekBalanceInfo: Codable, Equatable, Identifiable, Sendable {
    public let currency: String
    public let totalBalance: String
    public let grantedBalance: String
    public let toppedUpBalance: String

    public init(
        currency: String,
        totalBalance: String,
        grantedBalance: String,
        toppedUpBalance: String
    ) {
        self.currency = currency
        self.totalBalance = totalBalance
        self.grantedBalance = grantedBalance
        self.toppedUpBalance = toppedUpBalance
    }

    public var id: String { currency }

    public var displayTotal: String {
        Self.display(amount: totalBalance, currency: currency)
    }

    public var displayGranted: String {
        Self.display(amount: grantedBalance, currency: currency)
    }

    public var displayToppedUp: String {
        Self.display(amount: toppedUpBalance, currency: currency)
    }

    private static func display(amount: String, currency: String) -> String {
        switch currency.uppercased() {
        case "CNY": "¥\(amount)"
        case "USD": "$\(amount)"
        default: "\(currency.uppercased()) \(amount)"
        }
    }

    private enum CodingKeys: String, CodingKey {
        case currency
        case totalBalance = "total_balance"
        case grantedBalance = "granted_balance"
        case toppedUpBalance = "topped_up_balance"
    }
}

public enum DeepSeekBalanceError: LocalizedError, Equatable {
    case missingCredential
    case invalidCredential
    case httpStatus(Int)
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .missingCredential:
            "尚未配置 DeepSeek API Key。"
        case .invalidCredential:
            "API Key 无效或已失效，请重新配置。"
        case let .httpStatus(code):
            "余额服务返回 HTTP \(code)，请稍后重试。"
        case .invalidResponse:
            "余额服务返回了无法识别的数据。"
        }
    }
}

public struct DeepSeekBalanceClient {
    public static let endpoint = URL(string: "https://api.deepseek.com/user/balance")!

    public init() {}

    public func fetch(apiKey: String) async throws -> DeepSeekBalanceResponse {
        let credential = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !credential.isEmpty else {
            throw DeepSeekBalanceError.missingCredential
        }

        var request = URLRequest(
            url: Self.endpoint,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: 15
        )
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(credential)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DeepSeekBalanceError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            do {
                return try JSONDecoder().decode(DeepSeekBalanceResponse.self, from: data)
            } catch {
                throw DeepSeekBalanceError.invalidResponse
            }
        case 401:
            throw DeepSeekBalanceError.invalidCredential
        default:
            throw DeepSeekBalanceError.httpStatus(httpResponse.statusCode)
        }
    }
}
