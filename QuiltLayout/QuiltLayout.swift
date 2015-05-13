//
//  Copyright (c) 2015 Ramy Kfoury. All rights reserved.
//

import Foundation


@objc protocol QuiltLayoutDelegate {
    
    optional func collectionView(collectionView: UICollectionView, layout: QuiltLayout, insetsForItemAtIndexPath indexPath: NSIndexPath) -> UIEdgeInsets
    optional func collectionView(collectionView: UICollectionView, layout: QuiltLayout, blockSizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize
}

class QuiltLayout: UICollectionViewLayout {
    
    var direction: UICollectionViewScrollDirection = .Vertical {
        didSet {
            invalidateLayout()
        }
    }
    var blockPixels = CGSize(width: 100, height: 100) {
        didSet {
            invalidateLayout()
        }
    }
    var prelayoutEverything = true
    var delegate: QuiltLayoutDelegate?
    
    private var furthestBlockPoint: CGPoint {
        get { return self.furthestBlockPoint}
        set {
            self.furthestBlockPoint.x = max(self.furthestBlockPoint.x, newValue.x)
            self.furthestBlockPoint.y = max(self.furthestBlockPoint.y, newValue.y)
        }
    }
    private var firstOpenSpace = CGPointZero
    private var previousLayoutRect = CGRectZero
    private var lastIndexPathPlaced: NSIndexPath?
    private var previousLayoutAttributes: [AnyObject]?
    private var indexPathByPosition: [NSNumber: [NSNumber: NSIndexPath]]?
    private var positionByIndexPath: [NSNumber: [NSNumber: NSValue]]?
    
    override func collectionViewContentSize() -> CGSize {
        
        let isVertical = direction == .Vertical
        if let cv = collectionView {
            let contentRect = UIEdgeInsetsInsetRect(cv.frame, cv.contentInset)
            if isVertical {
                return CGSize(width: CGRectGetWidth(contentRect), height: blockPixels.height * (furthestBlockPoint.y+1))
            } else {
                CGSize(width: blockPixels.width * (furthestBlockPoint.x+1), height: CGRectGetHeight(contentRect))
            }
        }
        return CGSizeZero
    }
    
    override func layoutAttributesForElementsInRect(rect: CGRect) -> [AnyObject]? {
        if CGRectEqualToRect(rect, previousLayoutRect) {
            return previousLayoutAttributes
        }
        previousLayoutRect = rect
        
        let isVertical = direction == .Vertical
        
        var unrestrictedDimensionStart = Int(isVertical ? CGRectGetMinY(rect) / blockPixels.height : CGRectGetMinX(rect) / blockPixels.width)
        var unrestrictedDimensionLength = 1 + Int(isVertical ? CGRectGetHeight(rect) / blockPixels.height : CGRectGetWidth(rect) / blockPixels.width)
        var unrestrictedDimensionEnd: Int = unrestrictedDimensionStart + unrestrictedDimensionLength
        
        fillInBlocks(toUnrestrictedRow: prelayoutEverything ? Int.max : unrestrictedDimensionEnd)
        
        var attributes = [UICollectionViewLayoutAttributes]()
        
        traverseTilesBetween(unrestrictedDimensionStart: unrestrictedDimensionStart, unrestrictedDimensionEnd: unrestrictedDimensionEnd) {
            [unowned self] (point) -> Bool in
            if let indexPath = self.indexPath(forPosition: point) {
                attributes.append(self.layoutAttributesForItemAtIndexPath(indexPath))
            }
            return true
        }
        
        previousLayoutAttributes = attributes
        return previousLayoutAttributes
    }
    
    override func layoutAttributesForItemAtIndexPath(indexPath: NSIndexPath) -> UICollectionViewLayoutAttributes! {
        var insets = delegate?.collectionView?(collectionView!, layout: self, insetsForItemAtIndexPath: indexPath) ?? UIEdgeInsetsZero
        var rect = frame(forIndexPath: indexPath)
        var attributes = UICollectionViewLayoutAttributes(forCellWithIndexPath: indexPath)
        attributes.frame = UIEdgeInsetsInsetRect(rect, insets)
        return attributes
    }
    
    override func shouldInvalidateLayoutForBoundsChange(newBounds: CGRect) -> Bool {
        return !CGSizeEqualToSize(newBounds.size, collectionView!.frame.size)
    }
    
    override func prepareForCollectionViewUpdates(updateItems: [AnyObject]!) {
        super.prepareForCollectionViewUpdates(updateItems)
        for item in updateItems as! [UICollectionViewUpdateItem] {
            if item.updateAction == .Insert || item.updateAction == .Move {
                fillInBlocks(toIndexPath: item.indexPathAfterUpdate!)
            }
        }
    }
    
    override func invalidateLayout() {
        super.invalidateLayout()
        furthestBlockPoint = CGPointZero
        firstOpenSpace = CGPointZero
        previousLayoutAttributes = nil
        previousLayoutRect = CGRectZero
        lastIndexPathPlaced = nil
        clearPositions()
    }
    
    override func prepareLayout() {
        super.prepareLayout()
        if delegate == nil {
            return
        }
        if let cv = collectionView {
            let isVertical = direction == .Vertical
            let scrollFrame = CGRect(origin: CGPoint(x: cv.contentOffset.x, y: cv.contentOffset.y),
                size: cv.frame.size)
            var unrestrictedRow = 1 + Int(isVertical ? CGRectGetMaxY(scrollFrame) / blockPixels.height : CGRectGetMaxX(scrollFrame) / blockPixels.width)
            fillInBlocks(toUnrestrictedRow: prelayoutEverything ? Int.max : unrestrictedRow)
        }
    }
    
    private func clearPositions() {
        indexPathByPosition = [NSNumber: [NSNumber: NSIndexPath]]()
        positionByIndexPath = [NSNumber: [NSNumber: NSValue]]()
    }
    
    private func frame(forIndexPath indexPath: NSIndexPath) -> CGRect {
        let isVertical = direction == .Vertical
        let point = position(forIndexPath: indexPath)
        let elementize = blockSize(forItemAtIndexPath: indexPath)
        if let cv = collectionView {
            let contentRect = UIEdgeInsetsInsetRect(cv.frame, cv.contentInset)
            if isVertical {
                let initialPadding = (CGRectGetWidth(contentRect) - CGFloat(restrictedDimensionBlockSize()) * blockPixels.width)/2
                return CGRect(x: point.x*blockPixels.width + initialPadding,
                    y: point.y*blockPixels.height,
                    width: elementize.width*blockPixels.width,
                    height: elementize.height*blockPixels.height)
            } else {
                let initialPadding = (CGRectGetWidth(contentRect) - CGFloat(restrictedDimensionBlockSize()) * blockPixels.width)/2
                return CGRect(x: point.x*blockPixels.width,
                    y: point.y*blockPixels.height + initialPadding,
                    width: elementize.width*blockPixels.width,
                    height: elementize.height*blockPixels.height)
            }
        }
        
        return CGRectZero
    }
    
    private func position(forIndexPath indexPath: NSIndexPath) -> CGPoint {
        let section = NSNumber(integer: indexPath.section)
        let row = NSNumber(integer: indexPath.row)
        // if item does not have a position, we will make one!
        if positionByIndexPath?[section]?[row] == nil {
            fillInBlocks(toIndexPath: indexPath)
        }
        return positionByIndexPath![section]![row]!.CGPointValue()
    }
    
    private func indexPath(forPosition point: CGPoint) -> NSIndexPath? {
        let isVertical = direction == .Vertical
        // to avoid creating unbounded nsmutabledictionaries we should
        // have the innerdict be the unrestricted dimension
        let unrestrictedPoint = NSNumber(integer: Int(isVertical ? point.y : point.x))
        let restrictedPoint = NSNumber(integer: Int(isVertical ? point.x : point.y))
        return indexPathByPosition?[restrictedPoint]?[unrestrictedPoint]
    }
    
    private func fillInBlocks(toIndexPath indexPath: NSIndexPath) {
        // we'll have our data structure as if we're planning
        // a vertical layout, then when we assign positions to
        // the items we'll invert the axis
        if let cv = collectionView {
            let sectionCount = cv.numberOfSections()
            let startIndex = lastIndexPathPlaced?.section ?? 0
            for section in startIndex..<sectionCount {
                let rowCount = cv.numberOfItemsInSection(section)
                let startRow = lastIndexPathPlaced == nil ? 0 : lastIndexPathPlaced!.row + 1
                for row in startRow..<rowCount {
                    if section >= indexPath.section && row > indexPath.row {
                        return
                    }
                    let newIndexPath = NSIndexPath(forRow: row, inSection: section)
                    if placeBlock(atIndex: newIndexPath) {
                        lastIndexPathPlaced = indexPath
                    }
                }
            }
        }
    }
    
    private func fillInBlocks(toUnrestrictedRow endRow: Int) {
        let isVertical = direction == .Vertical
        // we'll have our data structure as if we're planning
        // a vertical layout, then when we assign positions to
        // the items we'll invert the axis
        if let cv = collectionView {
            let sectionCount = cv.numberOfSections()
            let startIndex = lastIndexPathPlaced?.section ?? 0
            for section in startIndex..<sectionCount {
                let rowCount = cv.numberOfItemsInSection(section)
                let startRow = lastIndexPathPlaced == nil ? 0 : lastIndexPathPlaced!.row + 1
                for row in startRow..<rowCount {
                    let indexPath = NSIndexPath(forRow: row, inSection: section)
                    if placeBlock(atIndex: indexPath) {
                        lastIndexPathPlaced = indexPath
                    }
                    
                    // only jump out if we've already filled up every space up till the resticted row
                    if(Int(isVertical ? firstOpenSpace.y : firstOpenSpace.x) >= endRow) {
                        return
                    }
                }
            }
        }
    }
    
    private func placeBlock(atIndex indexPath: NSIndexPath) -> Bool {
        let size = blockSize(forItemAtIndexPath: indexPath)
        let isVertical = direction == .Vertical
        
        return !traverseOpenTiles {
            [unowned self] blockOrigin in
            
            // we need to make sure each square in the desired
            // area is available before we can place the square
            let didTraverseAllBlocks = self.traverseTiles(forPoint: blockOrigin, withSize: size, iterator: {
                [unowned self] point in
                let spaceAvailable: Bool = self.indexPath(forPosition: point) == nil
                let inBounds: Bool = Int(isVertical ? point.x : point.y) < self.restrictedDimensionBlockSize()
                let maximumRestrictedBoundSize: Bool = (isVertical ? blockOrigin.x : blockOrigin.y) == 0
                if spaceAvailable && maximumRestrictedBoundSize && !inBounds {
                    return true
                }
                
                return spaceAvailable && inBounds
            })
            
            if !didTraverseAllBlocks {
                return true
            }
            
            self.set(indexPath: indexPath, forPosition: blockOrigin)
            self.traverseTiles(forPoint: blockOrigin, withSize: size, iterator: {
                [unowned self] blockPoint in
                self.set(position: blockPoint, forIndexPath: indexPath)
                self.furthestBlockPoint = blockPoint
                return true
            })
            return false
        }
        
    }
    
    private func set(position point: CGPoint, forIndexPath indexPath: NSIndexPath) {
        let isVertical = direction == .Vertical
        // to avoid creating unbounded nsmutabledictionaries we should
        // have the innerdict be the unrestricted dimension
        let unrestrictedPoint = NSNumber(integer: Int(isVertical ? point.y : point.x))
        let restrictedPoint = NSNumber(integer: Int(isVertical ? point.x : point.y))
        
        let innerDict = indexPathByPosition?[restrictedPoint]
        if innerDict == nil {
            indexPathByPosition?[restrictedPoint] = [NSNumber: NSIndexPath]()
        }
        indexPathByPosition?[restrictedPoint]?[unrestrictedPoint] = indexPath
    }
    
    private func set(#indexPath: NSIndexPath, forPosition position: CGPoint) {
        let section = NSNumber(integer: indexPath.section)
        let row = NSNumber(integer: indexPath.row)
        let innerDict = positionByIndexPath?[section]
        if innerDict == nil {
            positionByIndexPath?[section] = [NSNumber: NSValue]()
        }
        positionByIndexPath?[section]?[row] =  NSValue(CGPoint: position)
    }
    
    private func traverseOpenTiles(iterator: CGPoint -> Bool) -> Bool {
        var allTakenBefore = true
        let isVertical = direction == .Vertical
        var unrestrictedDimensionStart = Int(isVertical ? firstOpenSpace.y : firstOpenSpace.x)
        for unrestrictedDimensionStart; ; unrestrictedDimensionStart++ {
            for restrictedDimension in 0..<restrictedDimensionBlockSize() {
                let point = CGPoint(x: isVertical ? restrictedDimension : unrestrictedDimensionStart, y: isVertical ? unrestrictedDimensionStart : restrictedDimension)
                
                if indexPath(forPosition: point) != nil {
                    continue
                }
                
                if allTakenBefore {
                    firstOpenSpace = point
                    allTakenBefore = false
                }
                
                if !iterator(point) {
                    return false
                }
            }
        }
    }
    
    private func traverseTiles(forPoint origin: CGPoint, withSize size: CGSize, iterator: CGPoint -> Bool) -> Bool {
        let startColumn =  Int(origin.x)
        let endColumn = Int(origin.x + size.width)
        for column in startColumn..<endColumn {
            let startRow =  Int(origin.y)
            let endRow =  Int(origin.y + size.height)
            for row in startRow..<endRow {
                if !iterator(CGPoint(x: column, y: row)) {
                    return false
                }
            }
        }
        return true
    }
    
    private func blockSize(forItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
        var blockSize = CGSize(width: 1, height: 1)
        if let cv = collectionView {
            blockSize = delegate?.collectionView?(cv, layout: self, blockSizeForItemAtIndexPath: indexPath) ?? blockSize
        }
        return CGSizeZero
    }
    
    private func traverseTilesBetween(unrestrictedDimensionStart start: Int, unrestrictedDimensionEnd end: Int, iterator: (CGPoint) -> Bool) -> Bool {
        let isVertical = direction == .Vertical
        for unrestrictedDimension in start..<end {
            for restrictedDimension in 0..<restrictedDimensionBlockSize() {
                let point = CGPoint(x: isVertical ? restrictedDimension : unrestrictedDimension, y: isVertical ? unrestrictedDimension : restrictedDimension)
                if !iterator(point) {
                    return false
                }
            }
        }
        
        return true
    }
    
    private func restrictedDimensionBlockSize() -> Int {
        let isVertical = direction == .Vertical
        if let cv = collectionView {
            let contentRect = UIEdgeInsetsInsetRect(cv.frame, cv.contentInset)
            let size = Int(isVertical ? CGRectGetWidth(contentRect) / blockPixels.width : CGRectGetHeight(contentRect) / blockPixels.height)
            if size == 0 {
                return 1
            }
            return size
        }
        return 0
    }
    
}