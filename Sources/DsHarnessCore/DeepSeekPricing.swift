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

    public static let models: [DeepSeekModelPricing] = [
        DeepSeekModelPricing(
            id: "deepseek-v4-flash",
            displayName: "V4 Flash",
            offPeak: DeepSeekTokenPrice(
                cacheHitInput: "¥0.01",
                cacheMissInput: "¥0.50",
                output: "¥1.00"
            ),
            peak: DeepSeekTokenPrice(
                cacheHitInput: "¥0.02",
                cacheMissInput: "¥1.00",
                output: "¥2.00"
            )
        ),
        DeepSeekModelPricing(
            id: "deepseek-v4-pro",
            displayName: "V4 Pro",
            offPeak: DeepSeekTokenPrice(
                cacheHitInput: "¥0.0125",
                cacheMissInput: "¥1.50",
                output: "¥3.00"
            ),
            peak: DeepSeekTokenPrice(
                cacheHitInput: "¥0.025",
                cacheMissInput: "¥3.00",
                output: "¥6.00"
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
