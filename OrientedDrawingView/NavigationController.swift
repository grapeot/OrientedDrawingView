//
//  NavigationControllerViewController.swift
//  OrientedDrawingView
//
//  Created by Dennis Lysenko on 10/6/15.
//  Copyright © 2015 Riff Digital. All rights reserved.
//

import UIKit

class NavigationController: UINavigationController {

    override func shouldAutorotate() -> Bool {
        return self.viewControllers.last is ViewController // ImageViewController doesn't autorotate
    }
    
    override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
        if self.viewControllers.last is ImageViewController {
            return [UIInterfaceOrientationMask.Portrait]
        } else {
            return [UIInterfaceOrientationMask.All]
        }
    }

}
