//
//  ViewController.swift
//  PersonSegmentation
//
//  Created by USER on 2022/02/08.
//

import UIKit
import Vision
import CoreImage.CIFilterBuiltins

class ViewController: UIViewController {

    @IBOutlet weak var selectButton: UIButton!
    @IBOutlet weak var frontImageView: UIImageView!
    @IBOutlet weak var backImageView: UIImageView!

    override func viewDidLoad() {
        super.viewDidLoad()
        backImageView.adjustMotionEffect()
    }

    var targetImage: UIImage? {
        didSet {
            let output = runMachineLearning(sourceImage: targetImage)
            setImageToImageViews(frontImage: output.frontImage, backImage: output.bgImage)
        }
    }

    @IBAction func selectButtonPressed() {
        let imagePicker = UIImagePickerController()
        imagePicker.sourceType = .photoLibrary
        imagePicker.allowsEditing = true
        imagePicker.delegate = self
        present(imagePicker, animated: true)
    }

    private func setImageToImageViews(frontImage: UIImage?, backImage: UIImage?) {
        frontImageView.image = frontImage
        backImageView.image = backImage
    }

    func runMachineLearning(sourceImage: UIImage?) -> (frontImage: UIImage?, bgImage: UIImage?) {
        guard let sourceImage = sourceImage else { return (nil, nil) }

        func requestPersonMask(sourceImage: UIImage) -> VNPixelBufferObservation? {
            let request = VNGeneratePersonSegmentationRequest()
            request.qualityLevel = .accurate
            request.outputPixelFormat = kCVPixelFormatType_OneComponent8
            let handler = VNImageRequestHandler(cgImage: sourceImage.cgImage!, options: [:])
            do {
                try handler.perform([request])
                return request.results!.first!
            } catch {
                print(error)
                return nil
            }
        }

        guard let personMask = requestPersonMask(sourceImage: sourceImage), let inputCGImage = sourceImage.cgImage else { return (nil, sourceImage) }
        let inputImage = CIImage(cgImage: inputCGImage)

        let maskImage = CIImage(cvPixelBuffer: personMask.pixelBuffer)
        let maskScaleX = inputImage.extent.width / maskImage.extent.width
        let maskScaleY = inputImage.extent.height / maskImage.extent.height
        let scaledPersonMaskImage: CIImage = maskImage.transformed(by: __CGAffineTransformMake(maskScaleX, 0, 0, maskScaleY, 0, 0))

        var croppingPersonMaskFilter: CIFilter & CIBlendWithMask {
            let blendFilter = CIFilter.blendWithMask()
            blendFilter.inputImage = inputImage
            blendFilter.maskImage = scaledPersonMaskImage
            return blendFilter
        }

        var personMaskBluringFilter: CIFilter & CIMaskedVariableBlur {
            let blurFilter = CIFilter.maskedVariableBlur()
            blurFilter.inputImage = inputImage
            blurFilter.mask = scaledPersonMaskImage
            blurFilter.radius = 10
            return blurFilter
        }

        func getFilteredImage(_ filter: CIFilter) -> UIImage? {
            guard let filteredImage = filter.outputImage,
                  let filteredCGImage = CIContext(options: nil).createCGImage(filteredImage, from: inputImage.extent) else { return nil }
            return UIImage(cgImage: filteredCGImage)
        }

        if let maskedImage = getFilteredImage(croppingPersonMaskFilter), let inverseMaskBluredBackgroundImage = getFilteredImage(personMaskBluringFilter) {
            return (maskedImage, inverseMaskBluredBackgroundImage)
        } else {
            return (nil, sourceImage)
        }
    }
}

extension ViewController: UIImagePickerControllerDelegate & UINavigationControllerDelegate {

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        var newImage: UIImage?
        if let editedImage = info[UIImagePickerController.InfoKey.editedImage] as? UIImage {
            newImage = editedImage
        } else if let originalImage = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
            newImage = originalImage
        }
        self.targetImage = newImage
        picker.dismiss(animated: true, completion: nil)
    }
}

extension UIView {

    func adjustMotionEffect(relativeValue: Int = 15) {
        // remove all motionEffects
        for effect in motionEffects {
            if let interpolatingEffect = effect as? UIInterpolatingMotionEffect {
                switch interpolatingEffect.keyPath {
                case "center.x", "center.y":
                    removeMotionEffect(interpolatingEffect)
                default: break
                }
            }
        }
        // add InterpolatingMotionEffects
        let centerX = UIInterpolatingMotionEffect(keyPath: "center.x", type: .tiltAlongHorizontalAxis)
        centerX.maximumRelativeValue = relativeValue
        centerX.minimumRelativeValue = -relativeValue
        let centerY = UIInterpolatingMotionEffect(keyPath: "center.y", type: .tiltAlongVerticalAxis)
        centerY.maximumRelativeValue = relativeValue
        centerY.minimumRelativeValue = -relativeValue
        let effectGroup = UIMotionEffectGroup()
        effectGroup.motionEffects = [centerX, centerY]
        addMotionEffect(effectGroup)
    }
}
