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

@class MGPScene;
@class MGPSceneNodeComponent;
@interface MGPSceneNode : NSObject

// On/Off
@property (nonatomic, getter=isEnabled) BOOL enabled;       // affects recursively

// Matrix
@property (nonatomic) matrix_float4x4 localToParentMatrix;
@property (nonatomic) matrix_float4x4 parentToLocalMatrix;
@property (nonatomic, readonly) matrix_float4x4 localToWorldMatrix;
@property (nonatomic, readonly) matrix_float4x4 worldToLocalMatrix;

@property (nonatomic, readonly) matrix_float4x4 localToWorldRotationMatrix;
@property (nonatomic, readonly) matrix_float4x4 worldToLocalRotationMatrix;

// Transform (Local)
@property (nonatomic) simd_float3 position;
@property (nonatomic) simd_float3 rotation;
@property (nonatomic) simd_float3 scale;

- (void)lookAt:(simd_float3)target;
- (void)lookAt:(simd_float3)target up:(simd_float3)up;

// Relations
@property (nonatomic, readonly) NSArray<MGPSceneNode*> *children;
@property (nonatomic, readonly) MGPSceneNode * _Nullable parent;
@property (nonatomic, readonly) MGPScene * _Nullable scene;

- (void)addChild: (MGPSceneNode *)node;
- (void)removeChild: (MGPSceneNode *)node;

// Components
@property (nonatomic, readonly) NSArray<MGPSceneNodeComponent *> *components;

- (void)addComponent: (MGPSceneNodeComponent *)component;
- (MGPSceneNodeComponent *)componentAtIndex: (NSUInteger)index;
- (MGPSceneNodeComponent *)componentOfType: (Class)theClass;
- (void)removeComponentAtIndex: (NSUInteger)index;
- (void)removeAllComponents;
- (void)removeComponentOfType: (Class)theClass;

@end

NS_ASSUME_NONNULL_END
