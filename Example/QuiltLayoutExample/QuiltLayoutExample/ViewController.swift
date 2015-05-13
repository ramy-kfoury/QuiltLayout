//
//  Copyright (c) 2015 Ramy Kfoury. All rights reserved.
//

import UIKit
import QuiltLayout

class ViewController: UICollectionViewController, UICollectionViewDataSource, UICollectionViewDelegate, QuiltLayoutDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()
        let layout = collectionView?.collectionViewLayout as! QuiltLayout
        layout.delegate = self
        let blockWidth = Int(CGRectGetWidth(collectionView!.frame) / 2)
        layout.blockPixels = CGSize(width: blockWidth, height: blockWidth)
    }
    
    override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("CellIdentifier", forIndexPath: indexPath) as! Cell
        cell.backgroundColor = UIColor.randomColor()
        cell.label.text = "\(indexPath.row)"
        return cell
    }
    
    override func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return 1
    }
    
    override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 20
    }
    
    func collectionView(collectionView: UICollectionView, layout: QuiltLayout, blockSizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
        return CGSize(width: 2, height: 1)
    }
    
    func collectionView(collectionView: UICollectionView, layout: QuiltLayout, insetsForItemAtIndexPath indexPath: NSIndexPath) -> UIEdgeInsets {
        return UIEdgeInsetsZero
    }
    
}

class Cell: UICollectionViewCell {
    @IBOutlet weak var label: UILabel!
}



extension UIColor {
    
    class func randomColor() -> UIColor{
        var randomRed:CGFloat = CGFloat(drand48())
        var randomGreen:CGFloat = CGFloat(drand48())
        var randomBlue:CGFloat = CGFloat(drand48())
        return UIColor(red: randomRed, green: randomGreen, blue: randomBlue, alpha: 1.0)
    }
}

