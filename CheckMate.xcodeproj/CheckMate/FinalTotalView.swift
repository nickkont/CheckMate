import SwiftUI
import UIKit

struct FinalTotalView: View {
    @ObservedObject var cameraModel: CameraModel
    @Environment(\.presentationMode) var presentationMode
    @State private var showSaveConfirmation = false
    @Binding var navigationPath: NavigationPath
    @State private var selectedPersonIndex = 0
    @State private var payingPersonIndex: Int? = nil
    @State private var currentPersonIndex = 0

    var body: some View {
        VStack {
            TabView(selection: $selectedPersonIndex) {
                ForEach(Array(cameraModel.people.enumerated()), id: \.element.id) { index, person in
                    PersonView(
                        person: person,
                        cameraModel: cameraModel,
                        selectedPersonIndex: $selectedPersonIndex,
                        payingPersonIndex: $payingPersonIndex,
                        showSaveConfirmation: $showSaveConfirmation,
                        navigationPath: $navigationPath,
                        currentPersonIndex: $currentPersonIndex
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
        }
        .background(Color.black.ignoresSafeArea())
        .alert(isPresented: $showSaveConfirmation) {
            Alert(title: Text("Saved!"), message: Text("Your receipt has been saved!"), dismissButton: .default(Text("OK")))
        }
    }
}

struct PersonView: View {
    let person: Person
    @ObservedObject var cameraModel: CameraModel
    @Binding var selectedPersonIndex: Int
    @Binding var payingPersonIndex: Int?
    @Binding var showSaveConfirmation: Bool
    @Binding var navigationPath: NavigationPath
    @Binding var currentPersonIndex: Int

    var body: some View {
        VStack {
            Text("\(person.name)'s Final Total")
                .font(.largeTitle)
                .foregroundColor(.white)
                .padding(.top, 20)

            let subtotal = calculateSubtotal(for: person)
            let proportionalTax = calculateProportionalTax(for: person)
            let proportionalTip = calculateProportionalTip(for: person)
            let finalTotal = subtotal + proportionalTax + proportionalTip

            Text("Subtotal: $\(String(format: "%.2f", subtotal))")
                .font(.title2)
                .foregroundColor(.white)

            if proportionalTax > 0 {
                Text("Tax: $\(String(format: "%.2f", proportionalTax))")
                    .foregroundColor(.white)
            }

            if proportionalTip > 0 {
                Text("Tip: $\(String(format: "%.2f", proportionalTip))")
                    .foregroundColor(.white)
            }

            Text("Total: $\(String(format: "%.2f", finalTotal))")
                .font(.title)
                .foregroundColor(.green)
                .bold()

            Spacer()
            displayOwedAmounts()
            
            Button(action: {
                saveReceipt(for: person, total: calculateTotal(for: person))
            }) {
                HStack {
                    Image(systemName: "tray.and.arrow.down.fill") 
                        .resizable()
                        .scaledToFit()
                        .frame(width: 25, height: 25)
                    
                    Text("Save Receipt")
                        .font(.headline)
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.bottom, 10)
            
            Button(action: {
                let amountOwed = String(format: "%.2f", finalTotal)
                let note = "Check split via CheckMate 🍽️"

                if let venmoURL = URL(string: "venmo://paycharge?txn=charge&amount=\(amountOwed)&note=\(note.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
                    if UIApplication.shared.canOpenURL(venmoURL) {
                        UIApplication.shared.open(venmoURL)
                    } else {
                        // Venmo app not installed – show alert or fallback
                        print("Venmo app is not installed.")
                    }
                }
            }) {
                HStack {
                    Image("venmoicon")
                        .resizable()
                        .frame(width: 25, height: 25)
                    Text("Request Money")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .padding()
                .background(Color.purple)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            
            Spacer()
            
            HStack(spacing: 20) {
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    if payingPersonIndex == selectedPersonIndex {
                        payingPersonIndex = nil
                    } else {
                        payingPersonIndex = selectedPersonIndex
                    }
                }) {
                    Image(systemName: "person.3.fill")
                        .font(.title)
                        .frame(width: 35, height: 35)
                        .foregroundColor(.white)
                        .padding(20)
                        .background(payingPersonIndex == selectedPersonIndex ? Color.red : Color.orange)
                        .clipShape(Circle())
                }

                Button(action: {
                    shareTotal(for: person)
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title)
                        .frame(width: 35, height: 35)
                        .foregroundColor(.white)
                        .padding(20)
                        .background(Color.orange)
                        .clipShape(Circle())
                }

                Button(action: {
                    saveImageWithOverlay(for: person, subtotal: subtotal, tax: proportionalTax, tip: proportionalTip, total: finalTotal)
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                }) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.title)
                        .frame(width: 35, height: 35)
                        .foregroundColor(.white)
                        .padding(20)
                        .background(Color.blue)
                        .clipShape(Circle())
                }

                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    currentPersonIndex = 0
                    resetCameraModel()
                    navigationPath.removeLast(navigationPath.count)
                }) {
                    Image(systemName: "checkmark")
                        .font(.title)
                        .frame(width: 35, height: 35)
                        .foregroundColor(.white)
                        .padding(20)
                        .background(Color.green)
                        .clipShape(Circle())
                }
            }
            .padding(.top, -40)
            .offset(y: -40)
        }
    }

    private func calculateSubtotal(for person: Person) -> Double {
        return person.selectedItems
            .compactMap { cameraModel.itemPriceMap[$0] }
            .compactMap { Double($0.replacingOccurrences(of: "$", with: "")) }
            .reduce(0, +)
    }

    @ViewBuilder
    private func displayOwedAmounts() -> some View {
        if let payerIndex = payingPersonIndex, payerIndex == selectedPersonIndex {
            VStack {
                Text("Friends Owe You:")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.top, 1)

                ForEach(cameraModel.people.indices, id: \.self) { otherIndex in
                    if otherIndex != payerIndex {
                        let otherPerson = cameraModel.people[otherIndex]
                        let amountOwed = calculateTotal(for: otherPerson)

                        Text("\(otherPerson.name) owes you: $\(String(format: "%.2f", amountOwed))")
                            .foregroundColor(.white)
                            .padding(.top, 2)
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.4))
            .cornerRadius(10)
        } else {
            EmptyView()
        }
    }

    private func calculateProportionalTax(for person: Person) -> Double {
        let totalSubtotal = cameraModel.people.map { calculateSubtotal(for: $0) }.reduce(0, +)
        guard totalSubtotal > 0 else { return 0 }
        return (calculateSubtotal(for: person) / totalSubtotal) * cameraModel.selectedTax
    }

    private func calculateProportionalTip(for person: Person) -> Double {
        let totalSubtotal = cameraModel.people.map { calculateSubtotal(for: $0) }.reduce(0, +)
        guard totalSubtotal > 0 else { return 0 }
        return (calculateSubtotal(for: person) / totalSubtotal) * cameraModel.selectedTip
    }

    private func calculateTotal(for person: Person) -> Double {
        return calculateSubtotal(for: person) + calculateProportionalTax(for: person) + calculateProportionalTip(for: person)
    }

    private func resetCameraModel() {
        cameraModel.stopSession()
        cameraModel.capturedImage = nil
        cameraModel.recognizedTextRegions = []
        cameraModel.people = [Person(name: "Person 1")]
        cameraModel.selectedItems.removeAll()
        cameraModel.selectedTax = 0
        cameraModel.selectedTip = 0
        cameraModel.selectedTotal = 0
        cameraModel.itemSelectionCounts.removeAll()
        cameraModel.originalItemPrices.removeAll()
        cameraModel.people = [Person(name: "Person 1")]
        
        DispatchQueue.main.async {
            currentPersonIndex = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            cameraModel.startSession()
        }
    }

    private func saveImageWithOverlay(for person: Person, subtotal: Double, tax: Double, tip: Double, total: Double) {
        guard let originalImage = cameraModel.capturedImage else { return }

        let renderer = UIGraphicsImageRenderer(size: originalImage.size)
        let finalImage = renderer.image { context in
            originalImage.draw(at: .zero)

            let textAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 60, weight: .bold),
                .foregroundColor: UIColor.white,
                .shadow: NSShadow()
            ]

            let textX = originalImage.size.width * 0.05
            let textY = originalImage.size.height * 0.75
            let lineSpacing: CGFloat = 70

            var textLines = [
                "\(person.name)'s Final Total",
                "Subtotal: $\(String(format: "%.2f", subtotal))",
                tax > 0 ? "Tax: $\(String(format: "%.2f", tax))" : nil,
                tip > 0 ? "Tip: $\(String(format: "%.2f", tip))" : nil,
                "Total: $\(String(format: "%.2f", total))",
                "Created on CheckMate"
            ].compactMap { $0 }

            if let payerIndex = payingPersonIndex, payerIndex == selectedPersonIndex {
                textLines.append("Friends Owe You:")
                for otherIndex in cameraModel.people.indices where otherIndex != payerIndex {
                    let otherPerson = cameraModel.people[otherIndex]
                    let amountOwed = calculateTotal(for: otherPerson)
                    textLines.append("\(otherPerson.name) owes you: $\(String(format: "%.2f", amountOwed))")
                }
            }

            for (index, line) in textLines.enumerated() {
                let textPosition = CGPoint(x: textX, y: textY + CGFloat(index) * lineSpacing)
                line.draw(at: textPosition, withAttributes: textAttributes)
            }
        }

        UIImageWriteToSavedPhotosAlbum(finalImage, nil, nil, nil)
        showSaveConfirmation = true
    }

    private func saveReceipt(for person: Person, total: Double) {
      
        var savedReceipts: [[String: Any]] = UserDefaults.standard.array(forKey: "savedReceipts") as? [[String: Any]] ?? []

        var receiptData: [[String: Any]] = []

        for person in cameraModel.people {
            let subtotal = calculateSubtotal(for: person)
            let proportionalTax = calculateProportionalTax(for: person)
            let proportionalTip = calculateProportionalTip(for: person)
            let finalTotal = subtotal + proportionalTax + proportionalTip

            let personData: [String: Any] = [
                "name": person.name,
                "subtotal": String(format: "%.2f", subtotal),
                "tax": String(format: "%.2f", proportionalTax),
                "tip": String(format: "%.2f", proportionalTip),
                "total": String(format: "%.2f", finalTotal)
            ]
            receiptData.append(personData)
        }

        let fullReceipt: [String: Any] = [
            "people": receiptData,
            "timestamp": Date().timeIntervalSince1970
        ]

        savedReceipts.append(fullReceipt)

        UserDefaults.standard.set(savedReceipts, forKey: "savedReceipts")

        

        DispatchQueue.main.async {
            showSaveConfirmation = true
        }
    }

    private func shareTotal(for person: Person) {
        let totalAmount = String(format: "%.2f", calculateTotal(for: person))
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        let dateTime = dateFormatter.string(from: Date())

        let message = "You owe me $\(totalAmount) for the bill at \(dateTime)."

        let activityViewController = UIActivityViewController(activityItems: [message], applicationActivities: nil)

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityViewController, animated: true, completion: nil)
        }
    }
}
