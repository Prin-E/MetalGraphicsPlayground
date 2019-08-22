//
//  MGPCamera.h
//  MetalGraphicsPlayground
//
//  Created by 이현우 on 22/05/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <simd/simd.h>
#import "MGPProjectionState.h"
#import "../../Shaders/SharedStructures.h"

NS_ASSUME_NONNULL_BEGIN

@class MGPFrustum;
@interface MGPCamera : NSObject

// world to camera
@property (readonly) matrix_float4x4 worldToCameraMatrix;
@property (readonly) matrix_float4x4 worldToCameraRotationMatrix;

// camera to world
@property (readonly) matrix_float4x4 cameraToWorldMatrix;
@property (readonly) matrix_float4x4 cameraToWorldRotationMatrix;

// projection
@property (readonly) matrix_float4x4 projectionMatrix;
@property MGPProjectionState projectionState;

// pos/rot
@property simd_float3 position;
@property simd_float3 rotation;     // euler xyz

// basis vectors
- (simd_float3)right;
- (simd_float3)up;
- (simd_float3)forward;

// camera setup
@property float fStop;
@property float shutterSpeed;
@property NSUInteger ISO;

@property (nonatomic, readonly) MGPFrustum *frustum;
@property (nonatomic, readonly) camera_props_t shaderProperties;

- (float)exposureValue;

@end

NS_ASSUME_NONNULL_END
