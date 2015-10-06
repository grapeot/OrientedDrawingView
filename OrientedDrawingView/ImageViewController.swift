//
//  ImageViewController.swift
//  OrientedDrawingView
//
//  Created by Dennis Lysenko on 10/6/15.
//  Copyright © 2015 Riff Digital. All rights reserved.
//

import UIKit

class ImageViewController: UIViewController {
    var image: UIImage!
    
    @IBOutlet weak var imageView: UIImageView!

    override func viewDidLoad() {
        super.viewDidLoad()

        self.imageView.image = self.image
    }
}
