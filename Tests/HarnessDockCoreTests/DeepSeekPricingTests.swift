import Testing
@testable import HarnessDockCore

struct DeepSeekPricingTests {
    @Test
    func returnsOfficialPricesForRequestedCurrency() {
        let cnyModels = DeepSeekAPIPricing.models(for: .cny)
        let usdModels = DeepSeekAPIPricing.models(for: .usd)

        #expect(cnyModels.first?.peak.cacheHitInput == "¥0.10")
        #expect(cnyModels.first { $0.id == "deepseek-v4-pro" }?.peak.output == "¥27.00")
        #expect(usdModels.first?.peak.cacheHitInput == "$0.014")
        #expect(usdModels.first { $0.id == "deepseek-v4-pro" }?.peak.output == "$3.96")
    }

    @Test
    func returnsOfficialSourceForRequestedCurrency() {
        #expect(
            DeepSeekAPIPricing.sourceURL(for: .cny).absoluteString
                == "https://api-docs.deepseek.com/zh-cn/quick_start/pricing/"
        )
        #expect(
            DeepSeekAPIPricing.sourceURL(for: .usd).absoluteString
                == "https://api-docs.deepseek.com/quick_start/pricing/"
        )
    }
}
