//
//  MGPCamera.h
//  MetalGraphicsPlayground
//
//  Created by 이현우 on 22/05/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <simd/simd.h>

NS_ASSUME_NONNULL_BEGIN

typedef struct _MGPProjectionState {
    BOOL isOrthographic;
    float aspectRatio;
    float orthographicSize;
    float fieldOfView;              // radian
    float nearPlane, farPlane;
} MGPProjectionState;

@interface MGPCamera : NSObject

// world to camera
@property (readonly) matrix_float4x4 cameraMatrix;
@property (readonly) matrix_float4x4 rotationMatrix;

// camera to world
@property (readonly) matrix_float4x4 cameraInverseMatrix;
@property (readonly) matrix_float4x4 rotationInverseMatrix;

// projection
@property (readonly) matrix_float4x4 projectionMatrix;
@property MGPProjectionState projectionState;

// pos/rot
@property simd_float3 position;
@property simd_float3 rotation;     // euler xyz

// camera setup
@property float fStop;
@property float shutterSpeed;
@property NSUInteger ISO;

- (float)exposureValue;

@end

NS_ASSUME_NONNULL_END
