//
//  YPImagePicker.swift
//  YPImgePicker
//
//  Created by Sacha Durand Saint Omer on 27/10/16.
//  Copyright © 2016 Yummypets. All rights reserved.
//

import UIKit
import AVFoundation

public class YPImagePicker: UINavigationController {
    
    /// Set a global configuration that will be applied whenever you call YPImagePicker().
    public static func setDefaultConfiguration(_ config: YPImagePickerConfiguration) {
        defaultConfiguration = config
    }
    
    private static var defaultConfiguration = YPImagePickerConfiguration()
    
    private let configuration: YPImagePickerConfiguration!
    private let picker: YPPickerVC!
    
    /// Get a YPImagePicker instance with the default configuration.
    public convenience init() {
        let defaultConf = YPImagePicker.defaultConfiguration
        self.init(configuration: defaultConf)
    }
    
    /// Get a YPImagePicker with the specified configuration.
    public required init(configuration: YPImagePickerConfiguration) {
        self.configuration = configuration
        picker = YPPickerVC(configuration: configuration)
        super.init(nibName: nil, bundle: nil)
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private let loadingContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(white: 0, alpha: 0.8)
        return view
    }()
    
    private let activityIndicatorView: UIActivityIndicatorView = {
        let aiv = UIActivityIndicatorView(activityIndicatorStyle: .whiteLarge)
        aiv.hidesWhenStopped = true
        aiv.translatesAutoresizingMaskIntoConstraints = false
        return aiv
    }()
    
    private let processingTitleLabel: UILabel = {
        let frame = CGRect(x: 0, y: 0, width: 200, height: 20)
        let label = UILabel(frame: frame)
        label.textColor = .white
        return label
    }()
    
    private func setupActivityIndicator() {
        self.view.addSubview(loadingContainerView)
        loadingContainerView.alpha = 0
        loadingContainerView.frame = self.view.bounds
        
        loadingContainerView.addSubview(processingTitleLabel)
        let labelWidth: CGFloat = 200.0
        let labelHeight: CGFloat = 20.0
        let offset: CGFloat = 40.0
        let frame = CGRect(x: (loadingContainerView.frame.width/2) - offset,
                           y: (loadingContainerView.frame.height/2) + offset,
                           width: labelWidth,
                           height: labelHeight)
        processingTitleLabel.frame = frame
        processingTitleLabel.text = configuration.wordings.processing
        
        loadingContainerView.addSubview(activityIndicatorView)
        activityIndicatorView.centerXAnchor.constraint(equalTo: loadingContainerView.centerXAnchor).isActive = true
        activityIndicatorView.centerYAnchor.constraint(equalTo: loadingContainerView.centerYAnchor).isActive = true
    }
    
    private func setupNavigationBar() {
        navigationBar.isTranslucent = false
        YPHelpers.changeBackButtonIcon(self, configuration: configuration)
    }
    
    func showHideActivityIndicator() {
        
        if !activityIndicatorView.isAnimating {
            activityIndicatorView.startAnimating()
            loadingContainerView.alpha = 1
        } else {
            activityIndicatorView.stopAnimating()
            loadingContainerView.alpha = 0
        }
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        picker.didClose = {
            self.configuration.delegate?.imagePickerDidCancel(self)
        }
        viewControllers = [picker]
        setupActivityIndicator()
        setupNavigationBar()
        
        picker.didSelectImage = { [unowned self] pickedImage, isNewPhoto in
            if self.configuration.showsFilters {
                let filterVC = YPFiltersVC(image: pickedImage, configuration: self.configuration)
                filterVC.didSelectImage = { filteredImage, isImageFiltered in
                    
                    let completion = { (image: UIImage) in
                        let mediaItem = YPMediaItem.photo(p: YPPhoto(image: image))
                        self.configuration.delegate?.imagePicker(self, didSelect: [mediaItem])
                        
                        if (isNewPhoto || isImageFiltered) && self.configuration.shouldSaveNewPicturesToAlbum {
                            YPPhotoSaver.trySaveImage(filteredImage, inAlbumNamed: self.configuration.albumName)
                        }
                    }
                    
                    if case let YPCropType.rectangle(ratio) = self.configuration.showsCrop {
                        let cropVC = YPCropVC(configuration: self.configuration, image: filteredImage, ratio: ratio)
                        cropVC.didFinishCropping = { croppedImage in
                            completion(croppedImage)
                        }
                        self.pushViewController(cropVC, animated: true)
                    } else {
                        completion(filteredImage)
                    }
                }
                
                // Use Fade transition instead of default push animation
                let transition = CATransition()
                transition.duration = 0.3
                transition.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
                transition.type = kCATransitionFade
                self.view.layer.add(transition, forKey: nil)
                
                self.pushViewController(filterVC, animated: false)
            } else {
                let completion = { (image: UIImage) in
                    let mediaItem = YPMediaItem.photo(p: YPPhoto(image: image))
                    self.configuration.delegate?.imagePicker(self, didSelect: [mediaItem])
                    
                    if isNewPhoto && self.configuration.shouldSaveNewPicturesToAlbum {
                        YPPhotoSaver.trySaveImage(pickedImage, inAlbumNamed: self.configuration.albumName)
                    }
                }
                if case let YPCropType.rectangle(ratio) = self.configuration.showsCrop {
                    let cropVC = YPCropVC(configuration: self.configuration, image: pickedImage, ratio: ratio)
                    cropVC.didFinishCropping = { croppedImage in
                        completion(croppedImage)
                    }
                    self.pushViewController(cropVC, animated: true)
                } else {
                    completion(pickedImage)
                }
            }
        }
        
        picker.didSelectVideo = { [unowned self] videoURL in
            createVideoItem(videoURL: videoURL,
                            activityIdicatorClosure: { _ in
                                self.showHideActivityIndicator()
            },
                            configuration: self.configuration,
                            completion: { video in
                                let mediaItem = YPMediaItem.video(v: video)
                                self.configuration.delegate?.imagePicker(self, didSelect: [mediaItem])
            })
        }
        
        picker.didSelectMultipleItems = { items in
            let selectionsGalleryVC = YPSelectionsGalleryVC.initWith(items: items,
                                                                     imagePicker: self,
                                                                     configuration: self.configuration)
            self.pushViewController(selectionsGalleryVC, animated: true)
        }
    }
}

