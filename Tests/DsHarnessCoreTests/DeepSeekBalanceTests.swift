import Foundation
import Testing
@testable import DsHarnessCore

struct DeepSeekBalanceTests {
    @Test
    func decodesOfficialResponseAndPrefersCNY() throws {
        let data = Data(#"""
        {
          "is_available": true,
          "balance_infos": [
            {
              "currency": "USD",
              "total_balance": "12.50",
              "granted_balance": "2.50",
              "topped_up_balance": "10.00"
            },
            {
              "currency": "CNY",
              "total_balance": "110.00",
              "granted_balance": "10.00",
              "topped_up_balance": "100.00"
            }
          ]
        }
        """#.utf8)

        let response = try JSONDecoder().decode(DeepSeekBalanceResponse.self, from: data)

        #expect(response.isAvailable)
        #expect(response.balanceInfos.count == 2)
        #expect(response.preferredInfo?.currency == "CNY")
        #expect(response.preferredInfo?.displayTotal == "¥110.00")
    }

    @Test
    func usesOfficialBalanceEndpoint() {
        #expect(
            DeepSeekBalanceClient.endpoint.absoluteString
                == "https://api.deepseek.com/user/balance"
        )
    }
}
