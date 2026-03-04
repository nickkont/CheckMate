import AVFoundation
import SwiftUI

class CameraModel: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    @Published var session = AVCaptureSession()
    @Published var capturedImage: UIImage?  // Store captured image
    @Published var recognizedTextRegions: [RecognizedTextRegion] = [] // Store recognized text regions
    @Published var selectedItems: [String] = [] // Store selected items
    @Published var itemPriceMap: [String: String] = [:] // Maps items to their prices
    @Published var manualTax: String = ""
    @Published var manualTip: String = ""
    @Published var manualTotal: String = ""
    @Published var selectedSubtotal: Double = 0
    @Published var selectedTax: Double = 0
    @Published var selectedTip: Double = 0
    @Published var selectedTotal: Double = 0
    @Published var userSubtotal: Double = 0
    @Published var userTaxShare: Double = 0
    @Published var userTipShare: Double = 0
    @Published var userGrandTotal: Double = 0
    @Published var userName: String = ""
    @Published var people: [Person] = [Person(name: "Person 1", selectedItems: [])]
    @Published var isFlashOn = false
    @Published var itemSelectionCounts: [String: Int] = [:]
    @Published var currentPersonIndex: Int = 0
    
    private let photoOutput = AVCapturePhotoOutput()
    
    override init() {
        super.init()
        setupCamera()
    }
    
    private func setupCamera() {
        session.beginConfiguration()
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            print("Failed to access camera")
            return
        }
        
        if session.canAddInput(input) { session.addInput(input) }
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        
        session.commitConfiguration()
    }
    
    func startSession() {
        DispatchQueue.global(qos: .background).async {
            self.session.startRunning()
        }
    }
    
    func stopSession() {
        DispatchQueue.global(qos: .background).async {
            self.session.stopRunning()
        }
    }
    
    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        settings.flashMode = isFlashOn ? .on : .off
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    func processCapturedImage(_ image: UIImage) {
        DispatchQueue.global(qos: .userInitiated).async {
            self.extractText(from: image) // ✅ Extract text exactly like a camera photo
        }
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            print("Failed to process image")
            return
        }
        
        DispatchQueue.main.async {
            self.capturedImage = image // Store full image (uncropped)
            self.extractText(from: image)
        }
    }
    func extractText(from image: UIImage) {
        TextRecognition.recognizeText(in: image) { recognizedRegions in
            DispatchQueue.main.async {
                let screenSize = UIScreen.main.bounds.size
                let scanRect = CGRect(
                    x: screenSize.width * 0.2,
                    y: screenSize.height * 0.25,
                    width: screenSize.width * 0.6,
                    height: screenSize.height * 0.5
                )
                
                // Convert all recognized text to lowercase before storing
                self.recognizedTextRegions = recognizedRegions
                    .map { region in
                        RecognizedTextRegion(text: region.text.lowercased(), boundingBox: region.boundingBox)
                    }
                    .filter { region in
                        let box = self.scaledBoundingBox(region.boundingBox, imageSize: image.size, viewSize: screenSize)
                        return scanRect.intersects(box)
                    }
                
                print("\n=== DEBUG: FILTERED TEXT INSIDE RECTANGLE ===")
                for region in self.recognizedTextRegions {
                    print("\(region.text) -> Bounding Box: \(region.boundingBox)")
                }
                
                self.pairItemsWithPrices()
            }
        }
    }
    func pairItemsWithPrices() {
        var itemToPriceMap: [String: String] = [:]
        
        let priceRegex = try! NSRegularExpression(pattern: #"^\$?\d+\.\d{2}$"#)
        
        let priceRegions = recognizedTextRegions.filter { region in
            let isPrice = priceRegex.firstMatch(in: region.text, options: [], range: NSRange(location: 0, length: region.text.utf16.count)) != nil
            return isPrice
        }
        
        let itemRegions = recognizedTextRegions.filter { region in
            !priceRegions.contains(where: { $0.id == region.id })
        }
        
        var detectedTax: String? = nil
        var detectedTip: String? = nil
        var detectedTotal: String? = nil
        
        for item in itemRegions {
            let lowercasedText = item.text.lowercased()
            
            if lowercasedText.contains("tax") {
                detectedTax = priceRegions.first(where: { $0.boundingBox.intersects(item.boundingBox) })?.text
                print("Detected TAX: \(detectedTax ?? "Not Found")")
            } else if lowercasedText.contains("tip") {
                detectedTip = priceRegions.first(where: { $0.boundingBox.intersects(item.boundingBox) })?.text
                print("Detected TIP: \(detectedTip ?? "Not Found")")
            }
        }
        
        for item in itemRegions {
            let lowercasedText = item.text.lowercased()
            
            if lowercasedText.contains("total") || (detectedTax != nil && lowercasedText.contains("subtotal")) {
                detectedTotal = priceRegions.first(where: { $0.boundingBox.intersects(item.boundingBox) })?.text
                print("Detected TOTAL: \(detectedTotal ?? "Not Found")")
                break
            }
        }
        
        if let tax = detectedTax {
            itemToPriceMap["tax"] = tax
        }
        if let tip = detectedTip {
            itemToPriceMap["tip"] = tip
        }
        if let total = detectedTotal {
            itemToPriceMap["total"] = total
        }
        
        for item in itemRegions {
            if itemToPriceMap.keys.contains(item.text) { continue }
            
            var tolerance: CGFloat = 0.01
            var foundPrice: String? = nil
            
            for attempt in 1...2 {
                let lineRect = CGRect(
                    x: item.boundingBox.midX - tolerance / 1.93,
                    y: item.boundingBox.midY,
                    width: tolerance,
                    height: 1 - item.boundingBox.maxY
                )
                
                let possiblePrices = priceRegions.filter { $0.boundingBox.intersects(lineRect) }
                
                if let closestPrice = possiblePrices.min(by: { $0.boundingBox.minY < $1.boundingBox.minY }) {
                    foundPrice = closestPrice.text
                    itemToPriceMap[item.text] = closestPrice.text
                    print("MATCHED: \(item.text) -> \(closestPrice.text) on attempt \(attempt)")
                    break
                }
                
       
                tolerance *= 2
            }
            
            if foundPrice == nil {
                print("NO PRICE FOUND for \(item.text) after retries")
            }
        }
        
        self.itemPriceMap = itemToPriceMap
        
        print("\n=== FINAL ITEM-PRICE MAPPINGS ===")
        for (item, price) in itemToPriceMap {
            print("\(item) -> \(price)")
        }
    }
    func getItemSelectionCount(for item: String) -> Int {
        return itemSelectionCounts[item] ?? 0
    }
    func toggleSelection(for text: String, personIndex: Int) {
        guard people.indices.contains(personIndex) else { return }
        
        let isItemName = itemPriceMap.keys.contains(text)

        if isItemName {
            if people[personIndex].selectedItems.contains(text) {
                let associatedPrice = itemPriceMap[text]
                people[personIndex].selectedItems.removeAll { $0 == text || $0 == associatedPrice }
                
                if let count = itemSelectionCounts[text], count > 1 {
                    itemSelectionCounts[text]! -= 1
                } else {
                    itemSelectionCounts.removeValue(forKey: text)
                }
            } else {
                people[personIndex].selectedItems.append(text)
                if let associatedPrice = itemPriceMap[text] {
                    people[personIndex].selectedItems.append(associatedPrice)
                }

                itemSelectionCounts[text, default: 0] += 1
            }
        }

        updateSplitPrices()
    }
    
    var originalItemPrices: [String: String] = [:]

    private func updateSplitPrices() {
        for (item, count) in itemSelectionCounts {
            guard let fullPrice = originalItemPrices[item] ?? itemPriceMap[item],
                  let priceValue = Double(fullPrice.replacingOccurrences(of: "$", with: "")) else { continue }

            if originalItemPrices[item] == nil {
                originalItemPrices[item] = fullPrice
            }

            if count > 1 {
                let perPersonPrice = priceValue / Double(count)
                itemPriceMap[item] = String(format: "$%.2f", perPersonPrice)
            } else {
                if let originalPrice = originalItemPrices[item] {
                    itemPriceMap[item] = originalPrice
                    originalItemPrices.removeValue(forKey: item)
                }
            }
        }
        objectWillChange.send() 
    }
    
    func scaledBoundingBox(_ boundingBox: CGRect, imageSize: CGSize, viewSize: CGSize) -> CGRect {
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

        let xOffset = viewSize.width * 0.08
        adjustedX += xOffset

        return CGRect(x: adjustedX, y: adjustedY, width: width, height: height)
    }
    func cropImageToSelectionBox(_ image: UIImage) -> UIImage? {
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

        if let croppedCGImage = cgImage.cropping(to: cropRect) {
            return UIImage(cgImage: croppedCGImage)
        }

        return nil
    }
    func toggleFlash() {
            isFlashOn.toggle()
        }
    
    func calculateUserTotal() {
        let selectedItemPrices = selectedItems.compactMap { itemPriceMap[$0] }.compactMap { Double($0.replacingOccurrences(of: "$", with: "")) }
        let subtotal = selectedItemPrices.reduce(0, +)

        let total = selectedTotal
        let tax = selectedTax
        let tip = selectedTip

        let percentageOfTotal = total > 0 ? subtotal / total : 0
        let taxShare = percentageOfTotal * tax
        let tipShare = percentageOfTotal * tip

        userSubtotal = subtotal
        userTaxShare = taxShare
        userTipShare = tipShare
        userGrandTotal = subtotal + taxShare + tipShare
    }
}
struct Person: Identifiable {
    let id = UUID()
    var name: String
    var selectedItems: [String] = []
    var isActive: Bool = true
}

