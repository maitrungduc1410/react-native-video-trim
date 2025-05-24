//
//  ProgressAlertController.swift
//  VideoTrim
//
//  Created by Duc Trung Mai on 20/5/25.
//

import UIKit

class ProgressAlertController: UIViewController {
    var onDismiss: (() -> Void)?
    
    private let titleLabel = UILabel()
    private let progressBar = UIProgressView(progressViewStyle: .default)
    private let actionButton = UIButton(type: .system)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupBackground()
        setupAlertView()
    }
    
    private func setupBackground() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.4)
    }
    
    private func setupAlertView() {
        let alertView = UIView()
        alertView.backgroundColor = UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1.0)
        alertView.layer.cornerRadius = 12
        alertView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(alertView)
        
        // AlertView Constraints
        NSLayoutConstraint.activate([
            alertView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            alertView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            alertView.widthAnchor.constraint(equalToConstant: 270)
        ])
        
        // Title Label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.textAlignment = .center
        titleLabel.font = UIFont.systemFont(ofSize: 18)
        titleLabel.numberOfLines = 0
        titleLabel.textColor = .white
        alertView.addSubview(titleLabel)
        
        // Progress Bar
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        alertView.addSubview(progressBar)
        
        // Action Button
        actionButton.setTitle("Cancel", for: .normal)
        actionButton.setTitleColor(.systemPink, for: .normal)
        actionButton.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        actionButton.addTarget(self, action: #selector(dismissAlert), for: .touchUpInside)
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        actionButton.isHidden = true
        alertView.addSubview(actionButton)
        
        // Constraints for titleLabel, progressBar, and actionButton
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: alertView.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: alertView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: alertView.trailingAnchor, constant: -16),
            
            progressBar.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            progressBar.leadingAnchor.constraint(equalTo: alertView.leadingAnchor, constant: 16),
            progressBar.trailingAnchor.constraint(equalTo: alertView.trailingAnchor, constant: -16),
            
            actionButton.topAnchor.constraint(equalTo: progressBar.bottomAnchor, constant: 16),
            actionButton.bottomAnchor.constraint(equalTo: alertView.bottomAnchor, constant: -16),
            actionButton.centerXAnchor.constraint(equalTo: alertView.centerXAnchor)
        ])
    }
    
    @objc private func dismissAlert() {
        self.onDismiss?()
    }
    
    func setTitle(_ text: String) {
        titleLabel.text = text
    }
    
    func setCancelTitle(_ text: String) {
        actionButton.setTitle(text, for: .normal)
    }
    
    func setProgress(_ progress: Float) {
        progressBar.setProgress(progress, animated: true)
    }
    
    func showCancelBtn() {
        // Ensure that the button is properly added to the view hierarchy and that the layout has been updated before hiding the button
        view.layoutIfNeeded()
        actionButton.isHidden = false
    }
}
