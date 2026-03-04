import GoogleMobileAds
import UIKit

class AdManager: NSObject, FullScreenContentDelegate {
    private var rewardedAd: RewardedAd?

    func loadRewardedAd() {
        let request = Request()
        RewardedAd.load(with: "ca-app-pub-8756228024271311/7314736435", // ✅ Test Ad Unit
                           request: request) { [weak self] ad, error in
            if let error = error {
                print("❌ Failed to load rewarded ad: \(error.localizedDescription)")
                return
            }
            self?.rewardedAd = ad
            self?.rewardedAd?.fullScreenContentDelegate = self
            print("✅ Rewarded ad loaded.")
        }
    }

    func showAd(from rootViewController: UIViewController) {
        guard let ad = rewardedAd else {
            print("⚠️ Ad not ready")
            return
        }

        ad.present(from: rootViewController) {
            let reward = ad.adReward
            print("🎉 User earned reward of \(reward.amount) \(reward.type)")
        }
    }

    // MARK: - Delegate Methods (Optional but recommended)
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("❌ Ad failed to present: \(error.localizedDescription)")
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("✅ Ad dismissed, loading new ad...")
        loadRewardedAd() // Reload for next time
    }
}
