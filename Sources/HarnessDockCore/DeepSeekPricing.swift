import Foundation

public enum DeepSeekPricingPeriod: String, Codable, Equatable, Sendable {
    case peak
    case offPeak

    public var displayName: String {
        switch self {
        case .peak: "高峰"
        case .offPeak: "谷时"
        }
    }
}

public enum DeepSeekPricingCurrency: String, Codable, Equatable, Sendable {
    case cny = "CNY"
    case usd = "USD"
}

public struct DeepSeekTokenPrice: Codable, Equatable, Sendable {
    public let cacheHitInput: String
    public let cacheMissInput: String
    public let output: String

    public init(cacheHitInput: String, cacheMissInput: String, output: String) {
        self.cacheHitInput = cacheHitInput
        self.cacheMissInput = cacheMissInput
        self.output = output
    }
}

public struct DeepSeekModelPricing: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let displayName: String
    public let offPeak: DeepSeekTokenPrice
    public let peak: DeepSeekTokenPrice

    public init(
        id: String,
        displayName: String,
        offPeak: DeepSeekTokenPrice,
        peak: DeepSeekTokenPrice
    ) {
        self.id = id
        self.displayName = displayName
        self.offPeak = offPeak
        self.peak = peak
    }
}

public struct DeepSeekPricingStatus: Equatable, Sendable {
    public let period: DeepSeekPricingPeriod
    public let nextTransition: Date
    public let nextPeriod: DeepSeekPricingPeriod

    public init(
        period: DeepSeekPricingPeriod,
        nextTransition: Date,
        nextPeriod: DeepSeekPricingPeriod
    ) {
        self.period = period
        self.nextTransition = nextTransition
        self.nextPeriod = nextPeriod
    }
}

public enum DeepSeekAPIPricing {
    public static let sourceURL = URL(
        string: "https://api-docs.deepseek.com/zh-cn/quick_start/pricing/"
    )!

    public static let models = models(for: .cny)

    public static func sourceURL(for currency: DeepSeekPricingCurrency) -> URL {
        switch currency {
        case .cny:
            sourceURL
        case .usd:
            URL(string: "https://api-docs.deepseek.com/quick_start/pricing/")!
        }
    }

    public static func models(for currency: DeepSeekPricingCurrency) -> [DeepSeekModelPricing] {
        switch currency {
        case .cny:
            cnyModels
        case .usd:
            usdModels
        }
    }

    private static let cnyModels: [DeepSeekModelPricing] = [
        DeepSeekModelPricing(
            id: "deepseek-v4-flash",
            displayName: "V4 Flash",
            offPeak: DeepSeekTokenPrice(
                cacheHitInput: "¥0.05",
                cacheMissInput: "¥1.50",
                output: "¥4.50"
            ),
            peak: DeepSeekTokenPrice(
                cacheHitInput: "¥0.10",
                cacheMissInput: "¥3.00",
                output: "¥9.00"
            )
        ),
        DeepSeekModelPricing(
            id: "deepseek-v4-pro",
            displayName: "V4 Pro",
            offPeak: DeepSeekTokenPrice(
                cacheHitInput: "¥0.15",
                cacheMissInput: "¥4.50",
                output: "¥13.50"
            ),
            peak: DeepSeekTokenPrice(
                cacheHitInput: "¥0.30",
                cacheMissInput: "¥9.00",
                output: "¥27.00"
            )
        ),
    ]

    private static let usdModels: [DeepSeekModelPricing] = [
        DeepSeekModelPricing(
            id: "deepseek-v4-flash",
            displayName: "V4 Flash",
            offPeak: DeepSeekTokenPrice(
                cacheHitInput: "$0.007",
                cacheMissInput: "$0.22",
                output: "$0.66"
            ),
            peak: DeepSeekTokenPrice(
                cacheHitInput: "$0.014",
                cacheMissInput: "$0.44",
                output: "$1.32"
            )
        ),
        DeepSeekModelPricing(
            id: "deepseek-v4-pro",
            displayName: "V4 Pro",
            offPeak: DeepSeekTokenPrice(
                cacheHitInput: "$0.022",
                cacheMissInput: "$0.66",
                output: "$1.98"
            ),
            peak: DeepSeekTokenPrice(
                cacheHitInput: "$0.044",
                cacheMissInput: "$1.32",
                output: "$3.96"
            )
        ),
    ]

    public static func period(at date: Date) -> DeepSeekPricingPeriod {
        let calendar = utcCalendar()
        let weekday = calendar.component(.weekday, from: date)
        guard (2...6).contains(weekday) else { return .offPeak }

        let hour = calendar.component(.hour, from: date)
        return (1..<4).contains(hour) || (6..<10).contains(hour)
            ? .peak
            : .offPeak
    }

    public static func status(at date: Date) -> DeepSeekPricingStatus {
        let currentPeriod = period(at: date)
        let transition = nextTransition(after: date)
        return DeepSeekPricingStatus(
            period: currentPeriod,
            nextTransition: transition,
            nextPeriod: period(at: transition)
        )
    }

    public static func nextTransition(after date: Date) -> Date {
        let calendar = utcCalendar()
        let startOfDay = calendar.startOfDay(for: date)

        for dayOffset in 0...8 {
            guard let day = calendar.date(
                byAdding: .day,
                value: dayOffset,
                to: startOfDay
            ) else {
                continue
            }
            let weekday = calendar.component(.weekday, from: day)
            guard (2...6).contains(weekday) else { continue }

            for hour in [1, 4, 6, 10] {
                guard let candidate = calendar.date(
                    bySettingHour: hour,
                    minute: 0,
                    second: 0,
                    of: day
                ), candidate > date
                else {
                    continue
                }
                return candidate
            }
        }

        preconditionFailure("A DeepSeek pricing transition must exist within eight days")
    }

    private static func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
