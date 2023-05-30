//
//  SceneHelper.swift
//  YOLOv8
//
//  Created by Jin on 2023-05-29.
//

import UIKit

class SceneHelper {
    static func getFirstWindowScene() -> UIWindowScene? {
        if #available(iOS 15, *) {
            return UIApplication.shared.connectedScenes.first(where: { $0 is UIWindowScene }) as? UIWindowScene
        } else {
            return UIApplication.shared.windows.first?.windowScene
        }
    }
}
