import SwiftUI

struct ManualFinalTotalView: View {
    var manualPeople: [ManualPerson]
    var manualTax: String
    var manualItems: [ManualItem]
    var manualTip: String
    
    @Binding var navigationPath: NavigationPath

    var body: some View {
        VStack {
            TabView {
                ForEach(manualPeople.indices, id: \.self) { index in
                    let person = manualPeople[index]
                    
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
                        
                        Button(action: {
                            navigationPath.removeLast(navigationPath.count)
                        }) {
                            Image(systemName: "checkmark.circle.fill")
                                .resizable()
                                .frame(width: 60, height: 60)
                                .foregroundColor(.green)
                                .padding()
                        }
                    }
                    .padding()
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
        }
        .background(Color.black.ignoresSafeArea())
    }
    
    private func countSelections() -> [UUID: Int] {
        var selectionCounts = [UUID: Int]()
        
        for person in manualPeople {
            for itemName in person.selectedItems {
                if let item = manualItems.first(where: { $0.name == itemName }) {
                    selectionCounts[item.id, default: 0] += 1
                }
            }
        }
        
        return selectionCounts
    }
    
    private func calculateSubtotal(for person: ManualPerson) -> Double {
        let selectionCounts = countSelections()
        
        return person.selectedItems
            .compactMap { itemName in
                if let item = manualItems.first(where: { $0.name == itemName }),
                   let price = Double(item.price.replacingOccurrences(of: "$", with: "")) {
                    let count = selectionCounts[item.id] ?? 1
                    return price / Double(count)
                }
                return nil
            }
            .reduce(0, +)
    }

    private func calculateProportionalTax(for person: ManualPerson) -> Double {
        let totalSubtotal = manualPeople
            .map { calculateSubtotal(for: $0) }
            .reduce(0, +)
        
        guard totalSubtotal > 0 else { return 0 }
        let tax = Double(manualTax.replacingOccurrences(of: "$", with: "")) ?? 0
        return (calculateSubtotal(for: person) / totalSubtotal) * tax
    }
    
    private func calculateProportionalTip(for person: ManualPerson) -> Double {
        let totalSubtotal = manualPeople
            .map { calculateSubtotal(for: $0) }
            .reduce(0, +)
        
        guard totalSubtotal > 0 else { return 0 }
        let tip = Double(manualTip.replacingOccurrences(of: "$", with: "")) ?? 0
        return (calculateSubtotal(for: person) / totalSubtotal) * tip
    }
}
