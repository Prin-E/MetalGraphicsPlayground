//
//  DeferredRenderer.h
//  MetalDeferred
//
//  Created by 이현우 on 03/05/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "../Common/Sources/Rendering/MGPRenderer.h"
#import "../Common/Sources/View/MGPView.h"
#import <simd/simd.h>

NS_ASSUME_NONNULL_BEGIN

@interface DeferredRenderer : MGPRenderer <MGPViewDelegate>

@property (readwrite) float roughness, metalic, anisotropy;

@property (readwrite) NSUInteger gBufferIndex;
@property (readwrite) BOOL ssaoOn, ssrOn;
@property (readwrite) float ssaoIntensity, ssaoRadius;
@property (readwrite) NSUInteger ssaoNumSamples;
@property (readwrite) float vignette, attenuation;
@property (readwrite) unsigned int numLights;

@end

NS_ASSUME_NONNULL_END
