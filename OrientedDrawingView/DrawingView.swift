//
//  DrawingView.swift
//  DrawingTest
//
//  Created by Dennis Lysenko on 10/6/15.
//  Copyright © 2015 Riff Digital. All rights reserved.
//

import UIKit

struct Action {
    var firstPoint: CGPoint
    var lastPoint: CGPoint?
    var sourcePath: CGMutablePath
    var sourceOrientation: UIDeviceOrientation
    var sourceBounds: CGSize
    var color: UIColor
    var strokeWidth: CGFloat
    
    init(firstPoint: CGPoint, sourceOrientation: UIDeviceOrientation, sourceBounds: CGSize, color: UIColor, strokeWidth: CGFloat) {
        self.sourceOrientation = sourceOrientation
        self.sourceBounds = sourceBounds
        self.color = color
        self.strokeWidth = strokeWidth
        self.firstPoint = firstPoint
        self.sourcePath = CGPathCreateMutable()
    }
    
    func getTransformedPath(orientation orientation: UIDeviceOrientation, bounds: CGSize) -> CGPath {
        // assuming we're going landscape to portrait or vice versa
        let smallerDimension: CGFloat = min(sourceBounds.width, sourceBounds.height)
        let largerDimension: CGFloat = max(sourceBounds.width, sourceBounds.height)
        
        let sourceAngle = self.sourceOrientation.angleDegrees
        let currentAngle = UIDevice.currentDevice().orientation.angleDegrees
        let diffDegrees = (currentAngle - sourceAngle + 360) % 360
        let diff = diffDegrees * CGFloat(M_PI) / 180
        let pi = CGFloat(M_PI)
        
        let isPortrait = self.sourceOrientation.isPortrait
        let isLandscape = !isPortrait
        
        let translatePoint: CGPoint
        if diff == pi {
            translatePoint = CGPoint(x: self.sourceBounds.width / 2, y: self.sourceBounds.height / 2)
        } else if (isPortrait && diff < pi) || (isLandscape && diff > pi) {
            translatePoint = CGPoint(x: largerDimension / 2, y: largerDimension / 2)
        } else {
            translatePoint = CGPoint(x: smallerDimension / 2, y: smallerDimension / 2)
        }

        let x = translatePoint.x
        let y = translatePoint.y
        var finalTransform = CGAffineTransformMake(cos(diff),sin(diff),-sin(diff),cos(diff),x-x*cos(diff)+y*sin(diff),y-x*sin(diff)-y*cos(diff));
        
        return CGPathCreateCopyByTransformingPath(self.sourcePath, &finalTransform)!
    }
    
    private func midpoint(p1 p1: CGPoint, p2: CGPoint) -> CGPoint {
        return CGPoint(x: (p1.x + p2.x) * 0.5, y: (p1.y + p2.y) * 0.5)
    }
    
    func addPathAndGetBoundingBox(beforePreviousPoint beforePreviousPoint: CGPoint, previousPoint: CGPoint, currentPoint: CGPoint) -> CGRect {
        let mid1 = midpoint(p1: beforePreviousPoint, p2: previousPoint)
        let mid2 = midpoint(p1: previousPoint, p2: currentPoint)
        
        let subpath = CGPathCreateMutable()
        CGPathMoveToPoint(subpath, nil, mid1.x, mid1.y)
        CGPathAddQuadCurveToPoint(subpath, nil, previousPoint.x, previousPoint.y, mid2.x, mid2.y)
        let bounds = CGPathGetBoundingBox(subpath)
        
        CGPathAddPath(self.sourcePath, nil, subpath)
        
        return bounds
    }
}

extension UIDeviceOrientation {
    var angleDegrees: CGFloat {
        switch self {
        case .LandscapeLeft: return 270
        case .LandscapeRight: return 90
        case .PortraitUpsideDown: return 180
        default: return 0
        }
    }
}

@IBDesignable public class DrawingView: UIView {
    @IBInspectable var lineColor: UIColor = UIColor.blueColor()
    @IBInspectable var lineWidth: CGFloat = 8
    
    private var allActions: [Action] = []
    private var currentAction: Action?
    
    public var isEmpty: Bool {
        return allActions.isEmpty
    }
    
    public func clear() {
        self.allActions = []
        self.setNeedsDisplay()
    }
    
    public func undo() {
        self.allActions.removeLast()
        self.setNeedsDisplay()
    }
    
    public override func drawRect(rect: CGRect) {
        self.drawActions(self.allActions)
    }
    
    public override func layoutSubviews() {
        self.setNeedsDisplay()
    }
    
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
    
    var previousPoint1, previousPoint2, currentPoint: CGPoint?
    public override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        guard let touch = touches.first else {
            return
        }
        
        self.previousPoint1 = touch.previousLocationInView(self)
        self.currentPoint = touch.locationInView(self)
        
        allActions.append(Action(firstPoint: touch.locationInView(self), sourceOrientation: UIDevice.currentDevice().orientation, sourceBounds: self.bounds.size, color: self.lineColor, strokeWidth: self.lineWidth))
        self.currentAction = allActions.last
    }
    
    public override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?) {
        guard let touch = touches.first else {
            return
        }
        
        self.previousPoint2 = previousPoint1;
        self.previousPoint1 = touch.previousLocationInView(self)
        self.currentPoint = touch.locationInView(self)
        
        guard let _ = self.currentAction?.addPathAndGetBoundingBox(beforePreviousPoint: self.previousPoint2!, previousPoint: self.previousPoint1!, currentPoint: self.currentPoint!) else {
            assert(false)
            return
        }
        
//        var drawBox = bounds
//        drawBox.origin.x -= self.lineWidth * 2
//        drawBox.origin.y -= self.lineWidth * 2
//        drawBox.size.width += self.lineWidth * 4
//        drawBox.size.height += self.lineWidth * 4
        self.setNeedsDisplay()
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