//
//  DrawingView.swift
//  DrawingTest
//
//  Created by Dennis Lysenko on 10/6/15.
//  Copyright © 2015 Riff Digital. All rights reserved.
//

import UIKit

extension CGPoint {
    /// Converts a point in the coordinate system x: [0, size.width] y: [0, size.height] to the coordinate system x: [0, 1] y: [0, 1].
    func normalizedToSize(size: CGSize) -> CGPoint {
        return CGPoint(x: self.x / size.width, y: self.y / size.height)
    }
}

extension UIDeviceOrientation {
    /// Gets the necessary angle to rotate by in order to compensate for device orientation.
    var angleDegrees: CGFloat {
        switch self {
        case .LandscapeLeft: return 270
        case .LandscapeRight: return 90
        case .PortraitUpsideDown: return 180
        default: return 0
        }
    }
}

/**
    Represents a single drawing action in a specific configuration.

    This allows you to create an "action" for drawing a line at the top when you were rotated to landscape and the drawing view was 320x568, then rotate to upside down portrait, size down the drawing view to 10x10, draw a line 3/4 of the way down from the new top, rotate to portrait and 320x320, and both lines will stretch perfectly to the same exact proportions they had relative to the drawing view in each of their source orientations & sizes.

    How? It stores a normalized path, meaning every point on it has an x and y value between 0 and 1. It also stores the orientation and DrawingView.bounds.size in which it was created (sourceOrientation and sourceBounds). As you add more subpaths to the path, it normalizes them based on sourceBounds. When it comes time to draw the path in a new configuration, it rotates the point about (0.5, 0.5) (ALWAYS the center after we've normalized the points :) by (newOrientation - sourceOrientation) degrees (see extension UIDeviceOrientation above) and then scales it to the new DrawingView bounds.
*/
struct Action {
    /// The orientation the device had when this action was started.
    var sourceOrientation: UIDeviceOrientation
    
    /// The bounds the parent drawing view had when this action was started.
    var sourceBounds: CGSize
    
    /// The color of the stroke.
    var color: UIColor
    var strokeWidth: CGFloat
    
    private var sourcePath: CGMutablePath
    
    
    init(sourceOrientation: UIDeviceOrientation, sourceBounds: CGSize, color: UIColor, strokeWidth: CGFloat) {
        self.sourceOrientation = sourceOrientation
        self.sourceBounds = sourceBounds
        self.color = color
        self.strokeWidth = strokeWidth
        self.sourcePath = CGPathCreateMutable()
    }
    
    
    /// Rotates & scales the source path. See class swiftdoc.
    func getTransformedPath(orientation orientation: UIDeviceOrientation, bounds: CGSize) -> CGPath {
        let sourceAngle = self.sourceOrientation.angleDegrees
        let currentAngle = UIDevice.currentDevice().orientation.angleDegrees
        let diffDegrees = (currentAngle - sourceAngle + 360) % 360
        let diff = diffDegrees * CGFloat(M_PI) / 180
        
        let x: CGFloat = 0.5
        let y: CGFloat = 0.5
        
        let sx: CGFloat = bounds.width
        let sy: CGFloat = bounds.height
        var finalTransform = CGAffineTransformMake(cos(diff),sin(diff),-sin(diff),cos(diff),x-x*cos(diff)+y*sin(diff),y-x*sin(diff)-y*cos(diff));
        
        finalTransform = CGAffineTransformConcat(finalTransform, CGAffineTransformMakeScale(sx, sy))
        
        return CGPathCreateCopyByTransformingPath(self.sourcePath, &finalTransform)!
    }
    
    
    /// Adds a smooth subpath to the drawing path.
    func addPathAndGetBoundingBox(var beforePreviousPoint beforePreviousPoint: CGPoint, var previousPoint: CGPoint, var currentPoint: CGPoint) -> CGRect {
        beforePreviousPoint = beforePreviousPoint.normalizedToSize(self.sourceBounds)
        previousPoint = previousPoint.normalizedToSize(self.sourceBounds)
        currentPoint = currentPoint.normalizedToSize(self.sourceBounds)
        
        let mid1 = midpoint(p1: beforePreviousPoint, p2: previousPoint)
        let mid2 = midpoint(p1: previousPoint, p2: currentPoint)
        
        let subpath = CGPathCreateMutable()
        CGPathMoveToPoint(subpath, nil, mid1.x, mid1.y)
        CGPathAddQuadCurveToPoint(subpath, nil, previousPoint.x, previousPoint.y, mid2.x, mid2.y)
        let bounds = CGPathGetBoundingBox(subpath)
        
        CGPathAddPath(self.sourcePath, nil, subpath)
        
        return bounds
    }
    
    private func midpoint(p1 p1: CGPoint, p2: CGPoint) -> CGPoint {
        return CGPoint(x: (p1.x + p2.x) * 0.5, y: (p1.y + p2.y) * 0.5)
    }
}

/**
    A view that accepts user drawing and displays it on screen.
    
    When rotated, this view will attempt to keep the same orientation on its drawing. Meaning, if you drew an arrow pointing to the HOME button and rotated your device to any other orientation, this DrawingView would rotate its internal display so that the arrow would still be pointing to the HOME button.
*/
@IBDesignable public class DrawingView: UIView {
    /// The color of lines that are drawn.
    @IBInspectable public var lineColor: UIColor = UIColor.blueColor()
    
    /// The stroke width of lines that are drawn.
    @IBInspectable public var lineWidth: CGFloat = 8
    
    
    private var allActions: [Action] = []
    private var redoQueue: [Action] = []
    private var currentAction: Action?
    
    /// True if the user has not drawn anything or has cleared the drawing view.
    public var isEmpty: Bool {
        return allActions.isEmpty
    }
    
    /// Deletes all content from the drawing view.
    public func clear() {
        self.allActions = []
        self.setNeedsDisplay()
    }
    
    /// Undoes the last action in the drawing queue.
    public func undo() {
        self.redoQueue.append(self.allActions.removeLast())
        self.setNeedsDisplay()
    }
    
    public func redo() {
        self.allActions.append(self.redoQueue.removeFirst())
        self.drawActions(self.allActions)
    }
    
    public func generateImage() -> UIImage {
        UIGraphicsBeginImageContextWithOptions(self.bounds.size, false, 0)
        self.drawRect(self.bounds)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
    
    
    // MARK: -
    public override func drawRect(rect: CGRect) {
        self.drawActions(self.allActions)
    }
    
    public override func layoutSubviews() {
        // Detects rotation and forces redisplay.
        self.setNeedsDisplay()
    }
    
    // TODO: cache current actions into an image
    private func drawActions(actions: [Action]) {
        let context = UIGraphicsGetCurrentContext()
        for action in actions {
            let path = action.getTransformedPath(orientation: UIDevice.currentDevice().orientation, bounds: self.bounds.size)
            CGContextAddPath(context, path)
            CGContextSetLineCap(context, CGLineCap.Round)
            CGContextSetLineWidth(context, action.strokeWidth)
            CGContextSetStrokeColorWithColor(context, action.color.CGColor)
            CGContextSetBlendMode(context, CGBlendMode.Normal)
            CGContextStrokePath(context)
        }
    }
    
    private func finalizeCurrentAction() {
        guard let _ = self.currentAction else {
            assert(false)
            return
        }
        
        self.currentAction = nil
    }
    
    private var previousPoint, beforePreviousPoint, currentPoint: CGPoint?
    public override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        guard let touch = touches.first else {
            return
        }
        
        self.previousPoint = touch.previousLocationInView(self)
        self.currentPoint = touch.locationInView(self)
        
        allActions.append(Action(sourceOrientation: UIDevice.currentDevice().orientation, sourceBounds: self.bounds.size, color: self.lineColor, strokeWidth: self.lineWidth))
        self.currentAction = allActions.last
    }
    
    public override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?) {
        guard let touch = touches.first else {
            return
        }
        
        self.beforePreviousPoint = previousPoint
        self.previousPoint = touch.previousLocationInView(self)
        self.currentPoint = touch.locationInView(self)
        
        guard let _ = self.currentAction?.addPathAndGetBoundingBox(beforePreviousPoint: self.beforePreviousPoint!, previousPoint: self.previousPoint!, currentPoint: self.currentPoint!) else {
            assert(false)
            return
        }
        
        var drawBox = bounds
        drawBox.origin.x -= self.lineWidth * 2
        drawBox.origin.y -= self.lineWidth * 2
        drawBox.size.width += self.lineWidth * 4
        drawBox.size.height += self.lineWidth * 4
        self.setNeedsDisplayInRect(drawBox)
        
        self.redoQueue = []
    }
    
    public override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
        self.touchesMoved(touches, withEvent: event)
    }
    
    public override func touchesCancelled(touches: Set<UITouch>?, withEvent event: UIEvent?) {
        if let _ = touches {
            self.touchesMoved(touches!, withEvent: event)
        }
    }
}