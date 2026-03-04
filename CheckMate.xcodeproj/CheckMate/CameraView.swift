import SwiftUI
import PhotosUI
import UIKit


struct CameraView: View {
    @StateObject private var cameraModel = CameraModel()
    @FocusState private var focusedItem: String?
    @State private var editedPrices: [String: String] = [:]
    @State private var editingItem: String? = nil
    @State private var showNameEntry = false
    @State private var currentPersonIndex = 0
    @State private var editingNameIndex: Int? = nil
    @State private var showTapHint = false
    @State private var isImagePickerPresented = false
    @State private var selectedImage: UIImage?
    @Binding var navigationPath: NavigationPath
    
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        focusedItem = nil
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }

                if let image = cameraModel.capturedImage {
                    ImageView(
                            image: image,
                            cameraModel: cameraModel,
                            currentPersonIndex: $currentPersonIndex,
                            showTapHint: $showTapHint,
                            focusedItem: $focusedItem,
                            editedPrices: $editedPrices,
                            editingItem: $editingItem,
                            editingNameIndex: $editingNameIndex,
                            navigationPath: $navigationPath
                        )
                } else {
                    CameraPreviewView(cameraModel: cameraModel, isImagePickerPresented: $isImagePickerPresented, selectedImage: $selectedImage, showTapHint: $showTapHint, currentPersonIndex: $currentPersonIndex)
                }
            }
            .sheet(isPresented: $isImagePickerPresented, onDismiss: {
                if let selectedImage = selectedImage {
                    cameraModel.capturedImage = selectedImage
                    cameraModel.extractText(from: selectedImage)
                }
            }) {
                
            }
            .onAppear {
                cameraModel.startSession()
            }
            .onChange(of: selectedImage) {
                if let newImage = selectedImage {
                    cameraModel.capturedImage = newImage
                    cameraModel.processCapturedImage(newImage)
                }
            }
            .onDisappear {
                cameraModel.stopSession()
            }
        }
    }
    
    private func previousPerson() {
        if currentPersonIndex > 0 {
            currentPersonIndex -= 1
        }
    }

    private func nextPerson() {
        if currentPersonIndex < cameraModel.people.count - 1 {
            currentPersonIndex += 1
        }
    }

    private func addNewPerson() {
        let newPerson = Person(name: "Person \(cameraModel.people.count + 1)", selectedItems: [])
        cameraModel.people.append(newPerson)
        currentPersonIndex = cameraModel.people.count - 1
    }
    
    private func showTapHintMessage() {
        withAnimation {
            showTapHint = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showTapHint = false
            }
        }
    }
    
    private func removeCurrentPerson() {
        guard cameraModel.people.count > 1 else { return }
        
        
        cameraModel.people[currentPersonIndex].isActive = false

     
        if let nextActiveIndex = cameraModel.people.firstIndex(where: { $0.isActive }) {
            currentPersonIndex = nextActiveIndex
        } else {
   
            cameraModel.people = [Person(name: "Person 1")]
            currentPersonIndex = 0
        }
    }
}

struct ImageView: View {
    let image: UIImage
    @ObservedObject var cameraModel: CameraModel
    @Binding var currentPersonIndex: Int
    @Binding var showTapHint: Bool
    @FocusState.Binding var focusedItem: String?
    @Binding var editedPrices: [String: String]
    @Binding var editingItem: String?
    @Binding var editingNameIndex: Int?
    @Binding var navigationPath: NavigationPath
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                
                ForEach(cameraModel.recognizedTextRegions.filter { region in
                    let text = region.text.trimmingCharacters(in: .whitespacesAndNewlines)
                    let isPrice = isLikelyPrice(text)
                    let isItemName = cameraModel.itemPriceMap.keys.contains(text.lowercased())
                    return isPrice || isItemName
                }, id: \.id) { region in
                    let text = region.text.trimmingCharacters(in: .whitespacesAndNewlines)
                    let isPrice = isLikelyPrice(text)

                    let box = self.scaledBoundingBox(region.boundingBox, imageSize: image.size, viewSize: geometry.size, isPrice: isPrice)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(getHighlightColor(for: text))
                        .frame(width: box.width, height: box.height)
                        .position(x: box.midX, y: box.midY)
                        .onTapGesture {
                            cameraModel.toggleSelection(for: text, personIndex: currentPersonIndex)
                        }
                }
                if showTapHint {
                    Text("Tap on what you ordered")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.4))
                        .cornerRadius(10)
                        .transition(.opacity)
                        .position(x: geometry.size.width / 2, y: geometry.size.height * 0.6)
                }
            }
        }
        .edgesIgnoringSafeArea(.all)
        
        VStack {
            Spacer()
            HStack {
                Button(action: {
                    cameraModel.capturedImage = nil
                    cameraModel.recognizedTextRegions = []
                    cameraModel.people[currentPersonIndex].selectedItems = []
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    resetAllData()
                }) {
                    Image(systemName: "xmark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .padding()
                        .background(Color.red)
                        .clipShape(Circle())
                        .foregroundColor(.white)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                }
                .padding(.leading, 30)
                .padding(.bottom, 50)
                Spacer()
            }
        }
        .padding()
        
        VStack {
            Spacer()
            if cameraModel.people.indices.contains(currentPersonIndex) && !cameraModel.people[currentPersonIndex].selectedItems.isEmpty {           SelectedItemsView(
                cameraModel: cameraModel,
                currentPersonIndex: $currentPersonIndex,
                focusedItem: $focusedItem,
                editedPrices: $editedPrices,
                editingItem: $editingItem,
                editingNameIndex: $editingNameIndex,
                navigationPath: $navigationPath
            )
            }
        }
    }
    private func isLikelyPrice(_ text: String) -> Bool {
        let priceRegex = #"^\$?\d+(\.\d{2})?$"#
        return text.range(of: priceRegex, options: .regularExpression) != nil
    }
    
    private func resetAllData() {
        cameraModel.capturedImage = nil
        cameraModel.recognizedTextRegions = []
        cameraModel.selectedItems.removeAll()
        cameraModel.itemPriceMap.removeAll()
        
        cameraModel.people.removeAll()
        cameraModel.people.append(Person(name: "Person 1"))
        
        cameraModel.itemSelectionCounts = [:]
        cameraModel.selectedTax = 0.0
        cameraModel.selectedTip = 0.0
        cameraModel.selectedTotal = 0.0
        
        
        currentPersonIndex = 0
    }
    
    private func scaledBoundingBox(_ boundingBox: CGRect, imageSize: CGSize, viewSize: CGSize, isPrice: Bool) -> CGRect {
        let scaleX = viewSize.width / imageSize.width
        let scaleY = viewSize.height / imageSize.height
        
        let x = boundingBox.origin.y * imageSize.width * scaleX
        let y = (1 - boundingBox.origin.x - boundingBox.width) * imageSize.height * scaleY
        let width = boundingBox.height * imageSize.width * scaleX
        let height = boundingBox.width * imageSize.height * scaleY
        
        let adjustedY = viewSize.height - y - height
        
        let imageAspectRatio = imageSize.width / imageSize.height
        let viewAspectRatio = viewSize.width / viewSize.height
        
        var adjustedX = x
        if imageAspectRatio > viewAspectRatio {
            let horizontalPadding = (viewSize.width - (imageSize.width * scaleY)) / 2
            adjustedX = x + horizontalPadding
        }
        
        
        let xOffset = isPrice ? viewSize.width * 0.15 : viewSize.width * 0.08
        adjustedX += xOffset
        
        return CGRect(x: adjustedX, y: adjustedY, width: width, height: height)
    }
    
    private func adjustedBoundingBox(_ boundingBox: CGRect, isPrice: Bool) -> CGRect {
        var adjustedBox = boundingBox
        
        if isPrice {
            adjustedBox.origin.x -= 10
        }
        
        return adjustedBox
    }
    
    private func getHighlightColor(for text: String) -> Color {
       
        let isSelectedByCurrentPerson = cameraModel.people[currentPersonIndex].selectedItems.contains(text)
        
        
        let isSelectedByOthers = cameraModel.people.indices.contains { index in
            index != currentPersonIndex && cameraModel.people[index].selectedItems.contains(text)
        }

       
        if isSelectedByOthers && isSelectedByCurrentPerson {
            return Color.purple.opacity(0.5)
        } else if isSelectedByCurrentPerson {
            return Color.green.opacity(0.3)
        } else if isSelectedByOthers {
            return Color.red.opacity(0.5)
        } else {
            return Color.blue.opacity(0.3)
        }
    }
}

import CoreMotion

struct CameraPreviewView: View {
    @ObservedObject var cameraModel: CameraModel
    @Binding var isImagePickerPresented: Bool
    @Binding var selectedImage: UIImage?
    @Binding var showTapHint: Bool
    @Binding var currentPersonIndex: Int
    @State private var showManualEntry = false
    @StateObject private var motionManager = MotionManager()
    @State private var showOrientationAlert = false
    
    var body: some View {
            ZStack {
                CameraPreview(session: cameraModel.session)
                    .ignoresSafeArea()

                Color.black.opacity(0.5)
                    .overlay(
                        ZStack {
                            Rectangle()
                                .frame(width: UIScreen.main.bounds.width * 0.6, height: UIScreen.main.bounds.height * 0.5)
                                .cornerRadius(20)
                                .blendMode(.destinationOut)

                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.black, lineWidth: 3)
                                .frame(width: UIScreen.main.bounds.width * 0.6, height: UIScreen.main.bounds.height * 0.5)
                        }
                    )
                    .compositingGroup()
                    .edgesIgnoringSafeArea(.all)

                Text("Place your receipt inside the box")
                    .foregroundColor(.white)
                    .font(.headline)
                    .padding(.top, UIScreen.main.bounds.height * 0.55)

                if showOrientationAlert {
                    Color.black.opacity(0.5)
                        .edgesIgnoringSafeArea(.all)
                        .onTapGesture {
                            showOrientationAlert = false
                        }

                    VStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 50, height: 50)
                            .foregroundColor(.yellow)
                            .padding()

                        Text("Hold your phone straight up or horizontal for the best results.")
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding()

                    }
                    .frame(width: UIScreen.main.bounds.width * 0.8)
                    .padding()
                    .background(Color.black.opacity(0.9))
                    .cornerRadius(20)
                    .shadow(radius: 10)
                }
            }
            .onReceive(Timer.publish(every: 0.01, on: .main, in: .common).autoconnect()) { _ in
                checkOrientation()
            }

            VStack {
                    BannerAdView(adUnitID: "ca-app-pub-8756228024271311/9895890098")
                    .frame(width: 321, height: 51)
                    .padding(.top, 10)
                Spacer()
                HStack {
                    Button(action: {
                        showManualEntry = true
                    }) {
                        Image(systemName: "list.bullet")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                            .padding(10)
                            .foregroundColor(.white)
                    }
                    .offset(x: -40)

                    Button(action: {
                        cameraModel.capturePhoto()
                        showTapHintMessage()
                        resetCurrentPersonIndex()
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    }) {
                        Image("Check")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 60)
                            .padding(12)
                            .background(Circle().fill(Color.white))
                            .overlay(Circle().stroke(Color.black, lineWidth: 3))
                    }
                    .offset(x: 0)

                    Button(action: {
                        cameraModel.toggleFlash()
                    }) {
                        Image(systemName: cameraModel.isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                            .padding(10)
                            .foregroundColor(.white)
                    }
                    .offset(x: 40)
                }
                .padding(.bottom, 40)
                .sheet(isPresented: $showManualEntry) {
                    ManualEntryView(isPresented: $showManualEntry)
                }
            }
        }
    private func checkOrientation() {
        let pitch = motionManager.pitch

        let verticalThreshold: ClosedRange<Double> = 1.4...1.6
        let horizontalThreshold: ClosedRange<Double> = -0.2...0.2

        let isVertical = verticalThreshold.contains(pitch)
        let isHorizontal = horizontalThreshold.contains(pitch)

        if !isVertical && !isHorizontal {
            showOrientationAlert = true
        } else {
            showOrientationAlert = false
        }
    }
    private func showTapHintMessage() {
        withAnimation {
            showTapHint = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showTapHint = false
            }
        }
    }
    
    private func resetCurrentPersonIndex() {
        DispatchQueue.main.async {
                currentPersonIndex = 0
            }
    }
}

struct SelectedItemsView: View {
    @ObservedObject var cameraModel: CameraModel
    @Binding var currentPersonIndex: Int
    @FocusState.Binding var focusedItem: String?
    @Binding var editedPrices: [String: String]
    @Binding var editingItem: String?
    @Binding var editingNameIndex: Int?
    @Binding var navigationPath: NavigationPath
    
    private var safeCurrentPerson: Person? {
        guard cameraModel.people.indices.contains(currentPersonIndex) else {
            return nil
        }
        return cameraModel.people[currentPersonIndex]
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Button(action: {
                    cameraModel.people[currentPersonIndex].selectedItems.removeAll()
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .resizable()
                        .frame(width: 20, height: 20)
                        .foregroundColor(.red)
                }
                if cameraModel.people.count > 1 {
                    Button(action: {
                        clearPersonSelections()
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .resizable()
                            .frame(width: 20, height: 20)
                            .foregroundColor(.orange)
                    }
                }
                
                Spacer()
                
                if editingNameIndex == currentPersonIndex {
                    HStack {
                        TextField("Enter name", text: Binding(
                            get: { cameraModel.people[currentPersonIndex].name },
                            set: { cameraModel.people[currentPersonIndex].name = $0 }
                        ))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 150)
                        .focused($focusedItem, equals: "name\(currentPersonIndex)")
                        
                        Button(action: {
                            editingNameIndex = nil
                            focusedItem = nil
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }) {
                            Text("Done")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(7)
                                .background(Color.blue)
                                .cornerRadius(5)
                        }
                    }
                } else {
                    HStack(spacing: 0) {
                        if cameraModel.people.indices.contains(currentPersonIndex) {
                            Text(cameraModel.people[currentPersonIndex].name)
                                .font(.headline)
                                .foregroundColor(cameraModel.people[currentPersonIndex].name.starts(with: "Person") ? .blue : .white)
                                .onTapGesture {
                                    editingNameIndex = currentPersonIndex
                                    focusedItem = "name\(currentPersonIndex)"
                                }
                            
                            Text("'s Selected Items")
                                .font(.headline)
                                .foregroundColor(.white)
                        } else {
                            Text("No Person Selected")
                                .font(.headline)
                                .foregroundColor(.red)
                        }
                    }
                }
                Spacer()
                
                if cameraModel.people.indices.contains(currentPersonIndex) {
                    NavigationLink(
                        destination: TaxTipTotalView(
                            cameraModel: cameraModel,
                            userName: cameraModel.people[currentPersonIndex].name,
                            navigationPath: $navigationPath
                            
                        )
                    ) {
                        Image(systemName: "checkmark.circle.fill")
                            .resizable()
                            .frame(width: 20, height: 20)
                            .foregroundColor(.green)
                    }
                }
            }
            .padding(.bottom, 5)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    
                    ForEach(safeCurrentPerson?.selectedItems ?? [], id: \.self) { item in
                        if let price = cameraModel.itemPriceMap[item] {
                            HStack {
                                Text(item)
                                    .font(.body)
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                if editingItem == item {
                                    TextField("Edit price", text: Binding(
                                        get: { editedPrices[item] ?? price },
                                        set: { editedPrices[item] = $0 }
                                    ))
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .keyboardType(.decimalPad)
                                    .frame(width: 80)
                                    .focused($focusedItem, equals: item)
                                    
                                    Button(action: {
                                        if let newPrice = editedPrices[item], !newPrice.isEmpty {
                                            cameraModel.itemPriceMap[item] = newPrice
                                        }
                                        editingItem = nil
                                        focusedItem = nil
                                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                    }) {
                                        Text("Done")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                            .padding(7)
                                            .background(Color.blue)
                                            .cornerRadius(5)
                                    }
                                } else {
                                    Text(price)
                                        .font(.body)
                                        .foregroundColor(.white)
                                        .onTapGesture {
                                            editingItem = item
                                        }
                                }
                            }
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(10)
                        }
                    }
                }
            }
            .frame(height: UIScreen.main.bounds.height * 0.15)
            
            HStack {
                Button(action: previousPerson) {
                    Image(systemName: "chevron.left.circle.fill")
                        .resizable()
                        .frame(width: 30, height: 30)
                        .foregroundColor(currentPersonIndex > 0 ? .white : .gray)
                }
                .disabled(currentPersonIndex == 0)
                
                Spacer()
                
                Button(action: nextPerson) {
                    Image(systemName: "chevron.right.circle.fill")
                        .resizable()
                        .frame(width: 30, height: 30)
                        .foregroundColor(currentPersonIndex < cameraModel.people.count - 1 ? .white : .gray)
                }
                .disabled(currentPersonIndex == cameraModel.people.count - 1)
                
                Spacer()
                
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
            }
            .padding(.top, 10)
        }
        .padding()
        .background(Color.gray.opacity(0.8))
        .cornerRadius(20)
        .padding(.horizontal, 20)
    }
    
    private func previousPerson() {
        if currentPersonIndex > 0 {
            currentPersonIndex -= 1
        }
    }
    
    private func nextPerson() {
        if currentPersonIndex < cameraModel.people.count - 1 {
            currentPersonIndex += 1
        }
    }
    
    private func addNewPerson() {
        let newPerson = Person(name: "Person \(cameraModel.people.count + 1)", selectedItems: [])
        cameraModel.people.append(newPerson)
        currentPersonIndex = cameraModel.people.count - 1
        
        if cameraModel.people[currentPersonIndex].selectedItems.isEmpty {
                cameraModel.people[currentPersonIndex].selectedItems.append(" ")
            }
    }
    
    private func removeCurrentPerson() {
        guard cameraModel.people.count > 1 else { return }

        
        cameraModel.people.remove(at: currentPersonIndex)

       
        if currentPersonIndex >= cameraModel.people.count {
            currentPersonIndex = max(0, cameraModel.people.count - 1)
        }
        
  
        DispatchQueue.main.async {
            if self.cameraModel.people.isEmpty {
                self.cameraModel.people.append(Person(name: "Person 1"))
                self.currentPersonIndex = 0
            }
        }
    }
    private func clearPersonSelections() {
        guard cameraModel.people.indices.contains(currentPersonIndex) else { return }
        
        let previouslySelectedItems = cameraModel.people[currentPersonIndex].selectedItems

        cameraModel.people[currentPersonIndex].selectedItems.removeAll()

        for item in previouslySelectedItems {
            if let count = cameraModel.itemSelectionCounts[item], count > 1 {
                cameraModel.itemSelectionCounts[item] = count - 1
            } else {
                cameraModel.itemSelectionCounts.removeValue(forKey: item)
            }
        }
        if cameraModel.people[currentPersonIndex].selectedItems.isEmpty {
                cameraModel.people[currentPersonIndex].selectedItems.append(" ")
            }
    }
}
