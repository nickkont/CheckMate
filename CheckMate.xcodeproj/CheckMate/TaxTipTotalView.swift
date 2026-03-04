import SwiftUI


struct TaxTipTotalView: View {
    @ObservedObject var cameraModel: CameraModel

    @State private var selectedTax: CGRect? = nil
    @State private var selectedTip: CGRect? = nil
    @State private var selectedTotal: CGRect? = nil
    @State private var navigateToFinalTotal = false
    @State private var taxAmount: Double? = nil
    @State private var tipAmount: Double? = nil
    @State private var totalAmount: Double? = nil
    @State private var showEditAlert = false
    @State private var manualTax = ""
    @State private var manualTip = ""
    @State private var manualTotal = ""
    var userName: String
    @Binding var navigationPath: NavigationPath

    
    private var filteredTextRegions: [RecognizedTextRegion] {
        let priceRegex = try! NSRegularExpression(pattern: #"^\$?\d+(\.\d{2})?$"#)
        return cameraModel.recognizedTextRegions.filter { region in
            let text = region.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let range = NSRange(location: 0, length: text.utf16.count)
            return priceRegex.firstMatch(in: text, options: [], range: range) != nil
        }
    }
    private var selectionStatusText: String {
        if selectedTotal == nil {
            return "Selecting: Subtotal"
        } else if selectedTip == nil {
            return "Selecting: Tip"
        } else if selectedTax == nil {
            return "Selecting: Tax"
        } else {
            return "Selection Complete"
        }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack {
                Text(selectionStatusText)
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                
                GeometryReader { geometry in
                    ZStack {
                        if let image = cameraModel.capturedImage,
                           let croppedImage = cropImageToSelectionBox(image) {
                            Image(uiImage: croppedImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .scaleEffect(1.5)
                                .rotationEffect(.degrees(90))
                            
                            
                            ForEach(filteredTextRegions.indices, id: \.self) { index in
                                let region = filteredTextRegions[index]
                                let imageSize = image.size
                                let croppedWidth = imageSize.width * 0.6
                                let croppedHeight = imageSize.height * 0.5
                                let croppedSize = CGSize(width: croppedWidth, height: croppedHeight)
                                
                                let box = scaledBoundingBox(
                                    region.boundingBox,
                                    imageSize: imageSize,
                                    croppedSize: croppedSize,
                                    viewSize: geometry.size
                                )
                                
                                
                                RecognizedRegionView(
                                    region: region,
                                    box: box,
                                    selectedTax: $selectedTax,
                                    selectedTip: $selectedTip,
                                    selectedTotal: $selectedTotal,
                                    assignValue: assignValue,
                                    selectedTotalAmount: totalAmount, 
                                    selectedTaxAmount: taxAmount,
                                    selectedTipAmount: tipAmount
                                )
                            }
                        }
                    }
                }
                .padding()
                
                Spacer()
                
           
                Button(action: {
                    if manualTax.isEmpty { manualTax = "0" }
                    if manualTip.isEmpty { manualTip = "0" }
                    showEditAlert = true
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                }) {
                    Image(systemName: "pencil.circle.fill")
                        .resizable()
                        .frame(width: 65, height: 65)
                        .foregroundColor(.white)
                }
                .offset(x: -40, y: 50)
                
                NavigationLink(value: "FinalTotalView") {
                    EmptyView()
                }
                .navigationDestination(for: String.self) { value in
                    if value == "FinalTotalView" {
                        FinalTotalView(cameraModel: cameraModel, navigationPath: $navigationPath)
                    }
                }
                
        
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    if selectedTotal != nil {
                        saveSelectedValues()
                        navigationPath.append("FinalTotalView")                }
                }) {
                    Image(systemName: "arrow.right")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 25, height: 25)
                        .padding(20)
                        .background(selectedTotal == nil ? Color.gray : Color.green)
                        .clipShape(Circle())
                        .foregroundColor(.white)
                }
                .disabled(selectedTotal == nil)
                .offset(x: 40, y: -15)
            }
            .background(Color.black.ignoresSafeArea())
            .alert("Edit Subtotal, Tax, or Tip", isPresented: $showEditAlert) {
                VStack {
                    TextField("Enter Subtotal", text: $manualTotal)
                        .keyboardType(.decimalPad)
                    TextField("Enter Tax", text: Binding(
                        get: { manualTax == "0" ? "" : manualTax },
                        set: { manualTax = $0.isEmpty ? "0" : $0 }
                    ))
                    .keyboardType(.decimalPad)
                    
                    TextField("Enter Tip", text: Binding(
                        get: { manualTip == "0" ? "" : manualTip },
                        set: { manualTip = $0.isEmpty ? "0" : $0 }
                    ))
                    .keyboardType(.decimalPad)
                }
                Button("Save") {
                    if let taxValue = Double(manualTax), taxValue > 0 {
                            taxAmount = taxValue
                            cameraModel.selectedTax = taxValue
                        }
                        if let tipValue = Double(manualTip), tipValue > 0 {
                            tipAmount = tipValue
                            cameraModel.selectedTip = tipValue
                        }
                        if let totalValue = Double(manualTotal), totalValue > 0 {
                            totalAmount = totalValue
                            cameraModel.selectedTotal = totalValue
                        }

                        print("🔄 Updated values -> Tax: \(cameraModel.selectedTax), Tip: \(cameraModel.selectedTip), Total: \(cameraModel.selectedTotal)")

                        showEditAlert = false
                }
                Button("Cancel", role: .cancel) { showEditAlert = false }
            }
        }
        .navigationDestination(for: String.self) { value in
                        if value == "FinalTotalView" {
                            FinalTotalView(cameraModel: cameraModel, navigationPath: $navigationPath)
                        }
                    }
    }
    
    

    private func assignValue(for box: CGRect, text: String) {
        guard let numericValue = extractNumericValue(from: text) else { return }

        if selectedTotal == box {
            selectedTotal = nil
            totalAmount = nil
        } else if selectedTip == box {
            selectedTip = nil
            tipAmount = nil
        } else if selectedTax == box {
            selectedTax = nil
            taxAmount = nil
        } else if selectedTotal == nil {
            selectedTotal = box
            totalAmount = numericValue
        } else if selectedTip == nil {
            selectedTip = box
            tipAmount = numericValue
        } else if selectedTax == nil {
            selectedTax = box
            taxAmount = numericValue
        }
    }

    private func extractNumericValue(from text: String) -> Double? {
        let sanitizedText = text.replacingOccurrences(of: "$", with: "")
        return Double(sanitizedText)
    }

    private func saveSelectedValues() {
        guard let totalAmount = totalAmount else { return }

        
        let subtotal = cameraModel.people
            .map { person in
                person.selectedItems
                    .compactMap { cameraModel.itemPriceMap[$0] }
                    .compactMap { extractNumericValue(from: $0) }
                    .reduce(0, +)
            }
            .reduce(0, +)

      
        guard subtotal > 0 else { return }

        let percentage = subtotal / totalAmount
        let calculatedTax = (taxAmount ?? 0) * percentage
        let calculatedTip = (tipAmount ?? 0) * percentage

     
        cameraModel.selectedSubtotal = subtotal
        cameraModel.selectedTax = calculatedTax
        cameraModel.selectedTip = calculatedTip
        cameraModel.selectedTotal = subtotal + calculatedTax + calculatedTip

    }

    private func scaledBoundingBox(_ boundingBox: CGRect, imageSize: CGSize, croppedSize: CGSize, viewSize: CGSize) -> CGRect {
    
        let cropX = imageSize.width * 0.2
        let cropY = imageSize.height * 0.25
        let cropWidth = imageSize.width * 0.6
        let cropHeight = imageSize.height * 0.5


        let originalX = boundingBox.origin.x * imageSize.width
        let originalY = (1 - boundingBox.origin.y - boundingBox.height) * imageSize.height
        let originalWidth = boundingBox.width * imageSize.width
        let originalHeight = boundingBox.height * imageSize.height

       
        if originalX < cropX || originalX + originalWidth > cropX + cropWidth ||
           originalY < cropY || originalY + originalHeight > cropY + cropHeight {
            return .zero
        }

      
        let adjustedX: CGFloat = ((originalY - cropY) / cropHeight) * viewSize.width
        let adjustedY: CGFloat = ((originalX - cropX) / cropWidth) * viewSize.height
        let adjustedWidth: CGFloat = (originalHeight / cropHeight) * viewSize.width
        let adjustedHeight: CGFloat = (originalWidth / cropWidth) * viewSize.height

      
        let mirroredX = viewSize.width - adjustedX - adjustedWidth

       
        let leftShift: CGFloat = -viewSize.width * 0.1

        let finalX = mirroredX + leftShift

        return CGRect(x: finalX, y: adjustedY, width: adjustedWidth, height: adjustedHeight)
    }

    private func cropImageToSelectionBox(_ image: UIImage) -> UIImage? {
        let screenSize = UIScreen.main.bounds.size
        let selectionBox = CGRect(
            x: screenSize.width * 0.2,
            y: screenSize.height * 0.25,
            width: screenSize.width * 0.6,
            height: screenSize.height * 0.5
        )

        guard let cgImage = image.cgImage else { return nil }

        let widthRatio = CGFloat(cgImage.width) / screenSize.width
        let heightRatio = CGFloat(cgImage.height) / screenSize.height

        let cropRect = CGRect(
            x: selectionBox.origin.x * widthRatio,
            y: selectionBox.origin.y * heightRatio,
            width: selectionBox.width * widthRatio,
            height: selectionBox.height * heightRatio
        ).integral

        return cgImage.cropping(to: cropRect).map { UIImage(cgImage: $0) }
    }
}


struct RecognizedRegionView: View {
    let region: RecognizedTextRegion
    let box: CGRect
    @Binding var selectedTax: CGRect?
    @Binding var selectedTip: CGRect?
    @Binding var selectedTotal: CGRect?
    let assignValue: (CGRect, String) -> Void
    
    let selectedTotalAmount: Double?
        let selectedTaxAmount: Double?
        let selectedTipAmount: Double?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(getBoxColor(for: box))
                .frame(width: box.width, height: box.height)
                .position(x: box.midX, y: box.midY)
                .onTapGesture {
                    assignValue(box, region.text)
                }

            if let label = labelText {
                Text(label)
                    .foregroundColor(.white)
                    .font(.caption)
                    .bold()
                    .padding(5)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(5)
                    .position(x: box.maxX + 30, y: box.midY)
            }
        }
    }

    private var labelText: String? {
            if selectedTotal == box, let total = selectedTotalAmount {
                return "Subtotal: \(String(format: "%.2f", total))"
            } else if selectedTax == box, let tax = selectedTaxAmount {
                return "Tax: \(String(format: "%.2f", tax))"
            } else if selectedTip == box, let tip = selectedTipAmount {
                return "Tip: \(String(format: "%.2f", tip))"
            }
            return nil
        }

    private func getBoxColor(for box: CGRect) -> Color {
        if selectedTax == box {
            return Color.red.opacity(0.5)
        } else if selectedTip == box {
            return Color.orange.opacity(0.5)
        } else if selectedTotal == box {
            return Color.green.opacity(0.5)
        } else {
            return Color.blue.opacity(0.3)
        }
    }
}

