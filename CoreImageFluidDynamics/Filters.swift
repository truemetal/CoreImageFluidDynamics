//
//  filters.swift
//  CoreImageFluidDynamics
//
//  Created by Simon Gladman on 16/01/2016.
//  Copyright © 2016 Simon Gladman. All rights reserved.
//
//  Based on https://github.com/jwagner/fluidwebgl


import CoreImage

// MARK: Veclocity advection

class AdvectionFilter: CIFilter
{
    var inputVelocity: CIImage?
    
    let advectionKernel = CIKernel(source:
        "kernel vec4 advection(sampler velocity) \n" +
        "{  \n" +
        "   vec2 d = destCoord(); \n" +
            
        "   vec2 v = (sample(velocity, samplerCoord(velocity)).xy - 0.5) * -2.0;" +

        "   vec2 advectedVelocity = sample(velocity, samplerTransform(velocity, d + v)).xy;" +
            
        "   return vec4(advectedVelocity.x, advectedVelocity.y, 0.0, 1.0);" +
        "}"
    )
    
    override var outputImage : CIImage!
    {
        if let inputVelocity = inputVelocity,
            let advectionKernel = advectionKernel
        {
            let arguments = [inputVelocity]
            let extent = inputVelocity.extent
        
            return advectionKernel.apply(extent: extent,
                roiCallback:
                {
                    (index, rect) in
                    return rect
                },
                arguments: arguments)
        }
        return nil
    }
}

// MARK: Divergence

class DivergenceFilter: CIFilter
{
    var inputVelocity: CIImage?
    
    let divergenceKernel = CIKernel(source:
        "kernel vec4 divergence(sampler velocity) \n" +
        "{  \n" +
        "   vec2 d = destCoord(); \n" +
        
        "   float y0 = sample(velocity, samplerTransform(velocity, d + vec2(0.0,-1.0))).y; \n" +
        "   float y1 = sample(velocity, samplerTransform(velocity, d + vec2(0.0,1.0))).y; \n" +
        "   float x0 = sample(velocity, samplerTransform(velocity, d + vec2(-1.0,0.0))).x; \n" +
        "   float x1 = sample(velocity, samplerTransform(velocity, d + vec2(1.0,0.0))).x; \n" +
            
        "   y0 = (y0 - 0.5) * 2.0; " +
        "   y1 = (y1 - 0.5) * 2.0; " +
        "   x0 = (x0 - 0.5) * 2.0; " +
        "   x1 = (x1 - 0.5) * 2.0; " +
            
        "   float diverge = ((x1-x0) + (y1-y0)) * 0.5; " +
        
        "   return vec4(diverge, 0.0, 0.0, 1.0); \n" +
        "}"
    )
    
    override var outputImage : CIImage!
    {
        if let inputVelocity = inputVelocity,
            let divergenceKernel = divergenceKernel
        {
            let arguments = [inputVelocity]
            let extent = inputVelocity.extent
            
            return divergenceKernel.apply(extent: extent,
                roiCallback:
                {
                    (index, rect) in
                    return rect
                },
                arguments: arguments)
        }
        return nil
    }
}

// MARK: Jacobi

class JacobiFilter: CIFilter
{
    var inputDivergence: CIImage?
    var inputPressure: CIImage?
    
    let jacobiKernel = CIKernel(source:
        "kernel vec4 jacobi(sampler divergence, sampler pressure) \n" +
        "{  \n" +
        "   vec2 d = destCoord(); \n" +
        
        "   float y0 = sample(pressure, samplerTransform(pressure, d + vec2(0.0,-1.0))).x; \n" +
        "   float y1 = sample(pressure, samplerTransform(pressure, d + vec2(0.0,1.0))).x; \n" +
        "   float x0 = sample(pressure, samplerTransform(pressure, d + vec2(-1.0,0.0))).x; \n" +
        "   float x1 = sample(pressure, samplerTransform(pressure, d + vec2(1.0,0.0))).x; \n" +
        
        "   float diverge = sample(divergence, samplerCoord(divergence)).x; \n" +
            
        "   float relaxed = (x0 + x1 + y0 + y1 + (-1.0 * diverge)) * 0.25175; \n" +
    
        "   return vec4(relaxed, 0.0, 0.0, 1.0); \n" +  // alpha: -1.0  beta: 0.25
        "}"
    )
    
    override var outputImage : CIImage!
    {
        if let inputDivergence = inputDivergence,
            let inputPressure = inputPressure,
            let jacobiKernel = jacobiKernel
        {
            let arguments = [inputDivergence, inputPressure]
            let extent = inputDivergence.extent
            
            return jacobiKernel.apply(extent: extent,
                roiCallback:
                {
                    (index, rect) in
                    return rect
                },
                arguments: arguments)
        }
        return nil
    }
}

// MARK Subtract Pressure Gradient

class SubtractPressureGradientFilter: CIFilter
{
    var inputVelocity: CIImage?
    var inputPressure: CIImage?
    
    let subtractPressureGradientKernel = CIKernel(source:
        "kernel vec4 subtractPressureGradient(sampler velocity, sampler pressure) \n" +
        "{  \n" +
        "   vec2 d = destCoord(); \n" +
        
        "   float y0 = sample(pressure, samplerTransform(pressure, d + vec2(0.0,-1.0))).x; \n" +
        "   float y1 = sample(pressure, samplerTransform(pressure, d + vec2(0.0,1.0))).x; \n" +
        "   float x0 = sample(pressure, samplerTransform(pressure, d + vec2(-1.0,0.0))).x; \n" +
        "   float x1 = sample(pressure, samplerTransform(pressure, d + vec2(1.0,0.0))).x; \n" +
            
        "   vec2 v = sample(velocity, samplerCoord(velocity)).xy; \n" +
        "   v = (v - 0.5) * 2.0; " +
        
        "   vec2 result = v - (vec2(x1 - x0, y1 - y0) * 0.5);" +
            
        "   return vec4((result + 1.0) / 2.0, 0.0, 1.0); \n" +
        "}"
    )
    
    override var outputImage : CIImage!
    {
        if let inputVelocity = inputVelocity,
            let inputPressure = inputPressure,
            let subtractPressureGradientKernel = subtractPressureGradientKernel
        {
            let arguments = [inputVelocity, inputPressure]
            let extent = inputVelocity.extent
            
            return subtractPressureGradientKernel.apply(extent: extent,
                roiCallback:
                {
                    (index, rect) in
                    return rect
                },
                arguments: arguments)
        }
        return nil
    }
}












