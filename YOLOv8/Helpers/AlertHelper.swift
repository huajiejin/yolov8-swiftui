//
//  AlertHelper.swift
//  YOLOv8
//
//  Created by Jin on 2023-05-29.
//

import UIKit

class AlertHelper {
    static func showAlert(title: String, message: String, buttonTitle: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: buttonTitle, style: .default))
        if let viewController = SceneHelper.getFirstWindowScene()?.windows.first?.rootViewController {
            viewController.present(alert, animated: true)
        }
    }
}
