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

// Material props
@property (readwrite) float roughness, metalic, anisotropy;

// Frustum culling
@property (readwrite) BOOL cullOn;
@property (readwrite) BOOL locksFrustum;

// G-buffer
@property (readwrite) NSUInteger gBufferIndex;

// Post-processing params
@property (readwrite) BOOL ssaoOn, ssrOn;
@property (readwrite) float ssaoIntensity, ssaoRadius;
@property (readwrite) NSUInteger ssaoNumSamples;
@property (readwrite) float vignette, attenuation;

// Lights
@property (readwrite) unsigned int numLights;
@property (readwrite) BOOL IBLOn;
@property (readwrite) BOOL anisotropyOn;

// Light culling
@property (readwrite) BOOL lightCullOn;
@property (readwrite) uint lightGridTileSize;

// Profiling
@property (readwrite) BOOL animate;

@end

NS_ASSUME_NONNULL_END
