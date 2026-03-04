import SwiftUI

struct SavedReceiptsView: View {
    @State private var savedReceipts: [[String: Any]] = UserDefaults.standard.array(forKey: "savedReceipts") as? [[String: Any]] ?? []
    @State private var adManager = AdManager() // ✅ Your existing ad manager instance

    var body: some View {
        NavigationView {
            VStack {
                if savedReceipts.isEmpty {
                    Text("No saved receipts")
                        .font(.title)
                        .foregroundColor(.gray)
                        .padding()
                } else {
                    List {
                        let indexedReceipts = Array(savedReceipts.enumerated())

                        ForEach(indexedReceipts, id: \.0) { index, receipt in
                            if let timestamp = receipt["timestamp"] as? TimeInterval,
                               let people = receipt["people"] as? [[String: Any]] {

                                let date = Date(timeIntervalSince1970: timestamp)
                                let formattedDate = formatDate(date)

                                Section(header: Text("Receipt on \(formattedDate)").font(.headline)) {
                                    let indexedPeople = Array(people.enumerated())

                                    ForEach(indexedPeople, id: \.0) { _, person in
                                        if let name = person["name"] as? String,
                                           let total = person["total"] as? String {
                                            HStack {
                                                Text(name)
                                                    .font(.headline)
                                                Spacer()
                                                Text("$\(total)")
                                                    .foregroundColor(.green)
                                                    .bold()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .onDelete(perform: deleteReceipt)
                    }
                }

                // ✅ Support Me Button with Ad
                Button(action: {
                    if let topVC = topMostViewController() {
                            adManager.showAd(from: topVC)
                        } else {
                            print("❌ Failed to get top view controller")
                        }

                }) {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                        Text("Support Me")
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.purple)
                    .cornerRadius(10)
                }
                .padding(.bottom)
            }
            .navigationTitle("Saved Receipts")
            .onAppear {
                adManager.loadRewardedAd() // ✅ Load ad on appear
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        return dateFormatter.string(from: date)
    }

    private func deleteReceipt(at offsets: IndexSet) {
        for index in offsets {
            savedReceipts.remove(at: index)
        }
        UserDefaults.standard.set(savedReceipts, forKey: "savedReceipts")
    }
    func topMostViewController() -> UIViewController? {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            
            var topController = rootVC
            while let presentedVC = topController.presentedViewController {
                topController = presentedVC
            }
            return topController
        }
        return nil
    }
}

