//
//  VideoTrimmerThumb.swift
//  VideoTrim
//
//  Created by Duc Trung Mai on 20/5/25.
//

import UIKit

@available(iOS 13.0, *)
class VideoTrimmerThumb: UIView {
    private var isActive = false
    
    private let leadingChevronImageView: UIImageView = {
        let imageView = UIImageView(image: UIImage(systemName: "chevron.compact.left"))
        imageView.contentMode = .scaleAspectFill
        imageView.tintColor = .black
        imageView.tintAdjustmentMode = .normal
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let trailingChevronView: UIImageView = {
        let imageView = UIImageView(image: UIImage(systemName: "chevron.compact.right"))
        imageView.contentMode = .scaleAspectFill
        imageView.tintColor = .black
        imageView.tintAdjustmentMode = .normal
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let wrapperView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let leadingView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 6
        view.layer.cornerCurve = .continuous
        view.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMinXMinYCorner]
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let trailingView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 6
        view.layer.cornerCurve = .continuous
        view.layer.maskedCorners = [.layerMaxXMaxYCorner, .layerMaxXMinYCorner]
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let topView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let bottomView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    let leadingGrabber: UIControl = {
        let control = UIControl()
        control.translatesAutoresizingMaskIntoConstraints = false
        return control
    }()
    
    let trailingGrabber: UIControl = {
        let control = UIControl()
        control.translatesAutoresizingMaskIntoConstraints = false
        return control
    }()
    
    let chevronWidth: CGFloat = 16
    let edgeHeight: CGFloat = 4
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        leadingView.addSubview(leadingChevronImageView)
        trailingView.addSubview(trailingChevronView)
        
        wrapperView.addSubview(leadingView)
        wrapperView.addSubview(trailingView)
        wrapperView.addSubview(topView)
        wrapperView.addSubview(bottomView)
        addSubview(wrapperView)
        
        wrapperView.addSubview(leadingGrabber)
        wrapperView.addSubview(trailingGrabber)
        
        setupConstraints()
        updateColor()
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Wrapper view constraints
            wrapperView.topAnchor.constraint(equalTo: self.topAnchor),
            wrapperView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            wrapperView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            wrapperView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            
            // Leading view constraints
            leadingView.topAnchor.constraint(equalTo: wrapperView.topAnchor),
            leadingView.bottomAnchor.constraint(equalTo: wrapperView.bottomAnchor),
            leadingView.leadingAnchor.constraint(equalTo: wrapperView.leadingAnchor),
            leadingView.widthAnchor.constraint(equalToConstant: chevronWidth),
            
            // Trailing view constraints
            trailingView.topAnchor.constraint(equalTo: wrapperView.topAnchor),
            trailingView.bottomAnchor.constraint(equalTo: wrapperView.bottomAnchor),
            trailingView.trailingAnchor.constraint(equalTo: wrapperView.trailingAnchor),
            trailingView.widthAnchor.constraint(equalToConstant: chevronWidth),
            
            // Top view constraints
            topView.topAnchor.constraint(equalTo: wrapperView.topAnchor),
            topView.leadingAnchor.constraint(equalTo: leadingView.trailingAnchor),
            topView.trailingAnchor.constraint(equalTo: trailingView.leadingAnchor),
            topView.heightAnchor.constraint(equalToConstant: edgeHeight),
            
            // Bottom view constraints
            bottomView.bottomAnchor.constraint(equalTo: wrapperView.bottomAnchor),
            bottomView.leadingAnchor.constraint(equalTo: leadingView.trailingAnchor),
            bottomView.trailingAnchor.constraint(equalTo: trailingView.leadingAnchor),
            bottomView.heightAnchor.constraint(equalToConstant: edgeHeight),
            
            // Leading Chevron ImageView constraints
            leadingChevronImageView.topAnchor.constraint(equalTo: leadingView.topAnchor, constant: 8),
            leadingChevronImageView.bottomAnchor.constraint(equalTo: leadingView.bottomAnchor, constant: -8),
            leadingChevronImageView.leadingAnchor.constraint(equalTo: leadingView.leadingAnchor, constant: 2),
            leadingChevronImageView.trailingAnchor.constraint(equalTo: leadingView.trailingAnchor, constant: -2),
            
            // Trailing Chevron ImageView constraints
            trailingChevronView.topAnchor.constraint(equalTo: trailingView.topAnchor, constant: 8),
            trailingChevronView.bottomAnchor.constraint(equalTo: trailingView.bottomAnchor, constant: -8),
            trailingChevronView.leadingAnchor.constraint(equalTo: trailingView.leadingAnchor, constant: 2),
            trailingChevronView.trailingAnchor.constraint(equalTo: trailingView.trailingAnchor, constant: -2),
            
            // Leading Grabber constraints
            leadingGrabber.topAnchor.constraint(equalTo: leadingView.topAnchor),
            leadingGrabber.bottomAnchor.constraint(equalTo: leadingView.bottomAnchor),
            leadingGrabber.leadingAnchor.constraint(equalTo: leadingView.leadingAnchor),
            leadingGrabber.trailingAnchor.constraint(equalTo: leadingView.trailingAnchor),
            
            // Trailing Grabber constraints
            trailingGrabber.topAnchor.constraint(equalTo: trailingView.topAnchor),
            trailingGrabber.bottomAnchor.constraint(equalTo: trailingView.bottomAnchor),
            trailingGrabber.leadingAnchor.constraint(equalTo: trailingView.leadingAnchor),
            trailingGrabber.trailingAnchor.constraint(equalTo: trailingView.trailingAnchor)
        ])
    }
    
    private func updateColor() {
        let color = UIColor.systemYellow
        leadingView.backgroundColor = color
        trailingView.backgroundColor = color
        topView.backgroundColor = color
        bottomView.backgroundColor = color
    }
}
