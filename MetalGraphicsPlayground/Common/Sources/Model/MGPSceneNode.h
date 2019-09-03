//
//  MGPSceneNode.h
//  MetalGraphicsPlayground
//
//  Created by 이현우 on 2019/09/01.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <simd/simd.h>

NS_ASSUME_NONNULL_BEGIN

@interface MGPSceneNode : NSObject

// Local<->Parent Matrix
@property (nonatomic) matrix_float4x4 localToParentMatrix;
@property (nonatomic) matrix_float4x4 parentToLocalMatrix;
@property (nonatomic, readonly) matrix_float4x4 localToWorldMatrix;
@property (nonatomic, readonly) matrix_float4x4 worldToLocalMatrix;

// Transform
@property (nonatomic) simd_float3 position;
@property (nonatomic) simd_float3 rotation;
@property (nonatomic) simd_float3 scale;

@property (nonatomic) NSArray<MGPSceneNode*> *children;
@property (nonatomic) MGPSceneNode *parent;

- (void)addChild: (MGPSceneNode *)node;
- (void)removeChild: (MGPSceneNode *)node;

@end

NS_ASSUME_NONNULL_END
