import SwiftUI

struct ManualEntryView: View {
    @Binding var isPresented: Bool

    @State private var manualItems: [ManualItem] = []
    @State private var manualTax: String = ""
    @State private var manualTip: String = ""
    @State private var manualTotal: String = ""
    @State private var editingPersonIndex: Int? = nil
    @FocusState private var focusedField: Int?
    @State private var isEditMode: Bool = true
    @State private var selectedItems: [Int: Set<UUID>] = [:]
    @State private var currentPersonIndex: Int = 0
    @State private var showPeopleSelection = false
    @State private var navigationPath = NavigationPath()
    
    @State private var manualPeople: [ManualPerson] = [ManualPerson(name: "Person 1", selectedItems: [])]

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack {
                headerView()

                List {
                    itemsSection()
                    totalsSection()
                }
                .listStyle(InsetGroupedListStyle())
                .background(Color.black.edgesIgnoringSafeArea(.all))
                
                Button(action: {
                            navigationPath.append("SavedReceiptsView")
                        }) {
                            HStack {
                                Image(systemName: "tray.full")
                                Text("View Saved Receipts")
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                        }
                        .padding(.top, 10)
                    

                if showPeopleSelection {
                    peopleSelectionSection()
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationDestination(for: String.self) { value in
                if value == "ManualFinalTotalView" {
                    ManualFinalTotalView(
                                manualPeople: manualPeople,
                                manualTax: manualTax,
                                manualItems: manualItems,
                                manualTip: manualTip,
                                navigationPath: $navigationPath
                            )
                    
                }else if value == "SavedReceiptsView" {
                    SavedReceiptsView()
                }
            }
        }
    }

    private func headerView() -> some View {
        HStack {
            Button(action: { isPresented = false }) {
                Image(systemName: "chevron.left")
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundColor(.white)
                    .padding()
            }
            Spacer()
            Text("Manual Entry")
                .font(.headline)
                .foregroundColor(.white)
            Spacer()
            Button(action: saveManualEntry) {
                Text(isEditMode ? "Save" : "Edit")
                    .foregroundColor(.white)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 20)
                    .background(Color.purple)
                    .cornerRadius(10)
            }
        }
        .padding()
    }

    @ViewBuilder
    private func itemsSection() -> some View {
        Section(header: Text("Items & Prices").foregroundColor(.white)) {
            ForEach($manualItems) { $item in
                itemRow(item: $item)
            }
            .onDelete(perform: deleteItem)

            if isEditMode {
                Button(action: {
                    manualItems.append(ManualItem(name: "", price: ""))
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Item")
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }

    private func itemRow(item: Binding<ManualItem>) -> some View {
        HStack {
            if !isEditMode {
                Button(action: { toggleSelection(for: item.wrappedValue.id) }) {
                    Image(systemName: selectedItems[currentPersonIndex]?.contains(item.wrappedValue.id) == true ? "circle.fill" : "circle")
                        .foregroundColor(getSelectionColor(for: item.wrappedValue.id))
                }
            }

            TextField("Item Name", text: item.name)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($focusedField, equals: item.wrappedValue.id.hashValue)
                .disabled(!isEditMode)

            TextField("Price", text: item.price)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.decimalPad)
                .focused($focusedField, equals: item.wrappedValue.id.hashValue)
                .disabled(!isEditMode)

            if focusedField == item.wrappedValue.id.hashValue && isEditMode {
                Button(action: dismissKeyboard) {
                    Text("Done")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(7)
                        .background(Color.blue)
                        .cornerRadius(5)
                }
                .padding(.leading, 10)
            }
        }
        .padding(.vertical, 5)
    }

    @ViewBuilder
    private func totalsSection() -> some View {
        Section(header: Text("Subtotal, Tax, and Tip").foregroundColor(.white)) {
            totalTextField(title: "Enter Total (Before Tax)", value: $manualTotal, fieldID: 1001)
            totalTextField(title: "Enter Tax (If Any)", value: $manualTax, fieldID: 1002)
            totalTextField(title: "Enter Tip", value: $manualTip, fieldID: 1003)
        }
    }

    private func totalTextField(title: String, value: Binding<String>, fieldID: Int) -> some View {
        HStack {
            TextField(title, text: value)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.decimalPad)
                .focused($focusedField, equals: fieldID)
                .disabled(!isEditMode)

            if focusedField == fieldID && isEditMode {
                Button(action: dismissKeyboard) {
                    Text("Done")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(7)
                        .background(Color.blue)
                        .cornerRadius(5)
                }
                .padding(.leading, 10)
            }
        }
    }

    @ViewBuilder
    private func peopleSelectionSection() -> some View {
        VStack {
            HStack {
             
                Button(action: previousPerson) {
                    Image(systemName: "chevron.left.circle.fill")
                        .resizable()
                        .frame(width: 30, height: 30)
                        .foregroundColor(currentPersonIndex > 0 ? .white : .gray)
                }
                .disabled(currentPersonIndex == 0)

                Spacer()

                HStack {
                    if editingPersonIndex == currentPersonIndex {
                        TextField("Enter name", text: $manualPeople[currentPersonIndex].name)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 150)
                            .focused($focusedField, equals: 2000)

                        Button(action: {
                            editingPersonIndex = nil
                            dismissKeyboard()
                        }) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    } else {
                        Text(manualPeople[currentPersonIndex].name)
                            .font(.headline)
                            .foregroundColor(.white)
                            .onTapGesture {
                                editingPersonIndex = currentPersonIndex
                            }

                        Image(systemName: "pencil")
                            .foregroundColor(.white)
                            .onTapGesture {
                                editingPersonIndex = currentPersonIndex
                            }
                    }
                }

                Spacer()

                Button(action: nextPerson) {
                    Image(systemName: "chevron.right.circle.fill")
                        .resizable()
                        .frame(width: 30, height: 30)
                        .foregroundColor(currentPersonIndex < manualPeople.count - 1 ? .white : .gray)
                }
                .disabled(currentPersonIndex == manualPeople.count - 1)
            }
            .padding()

            HStack {
                
                Spacer(minLength: 50)
                
                Button(action: addNewPerson) {
                    HStack {
                        Image(systemName: "person.fill.badge.plus")
                        Text("Add Person")
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
                }

                Spacer()

                Button(action: {
                    navigationPath.append("ManualFinalTotalView")
                }) {
                    Image(systemName: "checkmark.circle.fill")
                        .resizable()
                        .frame(width: 30, height: 30)
                        .foregroundColor(.green)
                }
                Spacer(minLength: 20)
            }
            .padding(.top, 10)
        }
    }

    
    private func previousPerson() {
        if currentPersonIndex > 0 {
            currentPersonIndex -= 1
        }
    }

    private func nextPerson() {
        if currentPersonIndex < manualPeople.count - 1 {
            currentPersonIndex += 1
        }
    }

    private func addNewPerson() {
        let newPerson = ManualPerson(name: "Person \(manualPeople.count + 1)", selectedItems: [])
        manualPeople.append(newPerson)
        currentPersonIndex = manualPeople.count - 1
    }

    private func saveManualEntry() {
        isEditMode.toggle()
        showPeopleSelection = !isEditMode

        if !isEditMode {
            manualPeople.removeAll()
            
            for index in 0..<currentPersonIndex + 1 {
                let personName = "Person \(index + 1)"
                let selectedItemIDs = selectedItems[index] ?? []

                let selectedItemsForPerson = manualItems
                    .filter { selectedItemIDs.contains($0.id) }
                    .map { $0.name }

                let newPerson = ManualPerson(name: personName, selectedItems: selectedItemsForPerson)
                manualPeople.append(newPerson)
            }
        }
    }

    private func toggleSelection(for itemID: UUID) {
        if selectedItems[currentPersonIndex]?.contains(itemID) == true {
            selectedItems[currentPersonIndex]?.remove(itemID)
        } else {
            selectedItems[currentPersonIndex, default: []].insert(itemID)
        }
        
        let selectedItemNames = selectedItems[currentPersonIndex]?
            .compactMap { itemID in
                manualItems.first { $0.id == itemID }?.name
            } ?? []
        
        manualPeople[currentPersonIndex].selectedItems = selectedItemNames
    }

    private func getSelectionColor(for itemID: UUID) -> Color {
        let count = selectedItems.values.filter { $0.contains(itemID) }.count
        return count > 1 ? .purple : (selectedItems[currentPersonIndex]?.contains(itemID) == true ? .blue : .red)
    }

    private func deleteItem(at offsets: IndexSet) {
        self.manualItems.remove(atOffsets: offsets)
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct ManualPerson {
    var name: String
    var selectedItems: [String]
}

struct ManualItem: Identifiable {
    let id = UUID()
    var name: String
    var price: String
}
