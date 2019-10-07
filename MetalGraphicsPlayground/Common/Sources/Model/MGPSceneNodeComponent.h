//
//  MGPSceneNodeComponent.h
//  MetalGraphicsPlayground
//
//  Created by 이현우 on 2019/10/07.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#include <Foundation/Foundation.h>
#include <simd/simd.h>

NS_ASSUME_NONNULL_BEGIN

@class MGPSceneNode;
@interface MGPSceneNodeComponent : NSObject

@property (nonatomic, getter=isEnabled) BOOL enabled;
@property (nonatomic, weak) MGPSceneNode *node;

// Matrices
@property (nonatomic, readonly) simd_float4x4 localToWorldMatrix;
@property (nonatomic, readonly) simd_float4x4 worldToLocalMatrix;
@property (nonatomic, readonly) simd_float4x4 localToWorldRotationMatrix;
@property (nonatomic, readonly) simd_float4x4 worldToLocalRotationMatrix;

// Transforms
@property (nonatomic, readonly) simd_float3 position;
@property (nonatomic, readonly) simd_float3 rotation;
@property (nonatomic, readonly) simd_float3 scale;

@end

NS_ASSUME_NONNULL_END
