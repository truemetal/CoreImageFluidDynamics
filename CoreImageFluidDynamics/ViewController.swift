//
//  ViewController.swift
//  CoreImageFluidDynamics
//
//  Created by Simon Gladman on 16/01/2016.
//  Copyright © 2016 Simon Gladman. All rights reserved.
//
//  Based on https://github.com/jwagner/fluidwebgl

import UIKit
import GLKit

let rect640x640 = CGRect(x: 0, y: 0, width: 640, height: 640)

class ViewController: UIViewController
{
    let velocityAccumulator = CIImageAccumulator(extent: rect640x640, format: CIFormat.ARGB8)
    let pressureAccumulator = CIImageAccumulator(extent: rect640x640, format: CIFormat.ARGB8)
    
    let advectionFilter = AdvectionFilter()
    let divergenceFilter = DivergenceFilter()
    let jacobiFilter  = JacobiFilter()
    let subtractPressureGradientFilter = SubtractPressureGradientFilter()

    lazy var imageView: GLKView =
    {
        [unowned self] in
        
        let imageView = GLKView()
        
        imageView.layer.borderColor = UIColor.gray.cgColor
        imageView.layer.borderWidth = 1
        imageView.layer.shadowOffset = CGSize(width: 0, height: 0)
        imageView.layer.shadowOpacity = 0.75
        imageView.layer.shadowRadius = 5
        
        imageView.context = self.eaglContext!
        imageView.delegate = self
        
        return imageView
    }()
    
    let eaglContext = EAGLContext(api: .openGLES2)
    
    lazy var ciContext: CIContext =
    {
        [unowned self] in
        
        return CIContext(eaglContext: self.eaglContext!,
                         options: [.workingColorSpace: NSNull()])
    }()
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        view.addSubview(imageView)
        
        velocityAccumulator?.setImage(CIImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.0)))
        
        let displayLink = CADisplayLink(target: self, selector: #selector(ViewController.step))
        displayLink.add(to: RunLoop.main, forMode: RunLoop.Mode.default)
    }
    
    @objc func step()
    {
        imageView.setNeedsDisplay()
    }
    
    override func viewDidLayoutSubviews()
    {
        imageView.frame = CGRect(origin: CGPoint(x: view.frame.midX - rect640x640.midX,
                y: view.frame.midY - rect640x640.midY),
            size: CGSize(width: rect640x640.width, height: rect640x640.height))
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        guard let touch = touches.first else
        {
            return
        }

        let locationInView = CGPoint(
            x: touch.location(in: imageView).x,
            y: 640 - touch.location(in: imageView).y)

        let previousLocationInView = CGPoint(
            x: touch.previousLocation(in: imageView).x,
            y: 640 - touch.previousLocation(in: imageView).y)

        let red = CIColor(red: 1, green: 0, blue: 0)
                
        let pressureImage = CIImage(color: red)
            .cropped(to: CGRect(
                origin: locationInView.offset(20),
                size: CGSize(width: 40, height: 40)))
            .applyingFilter("CIGaussianBlur",
                parameters: [kCIInputRadiusKey: 10])

        let deltaX = locationInView.x - previousLocationInView.x
        let deltaY = locationInView.y - previousLocationInView.y
                
        let directionX = ((max(min(deltaX, 10), -10)) / 20) + 0.5
        let directionY = ((max(min(deltaY, 10), -10)) / 20) + 0.5

        let directionColor = CIColor(red: directionX, green: directionY, blue: 0)
                
        let directionImage = CIImage(color: directionColor)
            .cropped(to: CGRect(
                origin: locationInView.offset(15),
                size: CGSize(width: 30, height: 30)))
            .applyingFilter("CIGaussianBlur",
                parameters: [kCIInputRadiusKey: 5])

        velocityAccumulator?.setImage(directionImage
            .composited(over: (velocityAccumulator?.image())!))

        pressureAccumulator?.setImage(pressureImage
            .composited(over: (pressureAccumulator?.image())!))
    }
    
}

extension CGPoint
{
    func offset(_ delta: CGFloat) -> CGPoint
    {
        return CGPoint(x: self.x - delta, y: self.y - delta)
    }
}

// MARK: GLKViewDelegate extension

extension ViewController: GLKViewDelegate
{
    func glkView(_ view: GLKView, drawIn rect: CGRect)
    {
        advectionFilter.inputVelocity = velocityAccumulator?.image()
        
        divergenceFilter.inputVelocity = advectionFilter.outputImage!

        jacobiFilter.inputDivergence = divergenceFilter.outputImage!
        
        for _ in 0 ... 3
        {
            jacobiFilter.inputPressure = pressureAccumulator?.image()
            
            pressureAccumulator?.setImage(jacobiFilter.outputImage)
        }
        
        subtractPressureGradientFilter.inputPressure = pressureAccumulator?.image()
        subtractPressureGradientFilter.inputVelocity = advectionFilter.outputImage
        
        velocityAccumulator?.setImage(subtractPressureGradientFilter.outputImage!)
        
        let finalImage = pressureAccumulator?.image()
            .applyingFilter("CIMaximumComponent", parameters: [:])
   
        ciContext.draw(finalImage!,
            in: CGRect(x: 0, y: 0,
                width: imageView.drawableWidth,
                height: imageView.drawableHeight),
            from: rect640x640)
    }
}
