//
//  MGPCameraComponent.h
//  MetalGraphicsPlayground
//
//  Created by 이현우 on 2019/10/07.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import "MGPSceneNodeComponent.h"
#import "MGPProjectionState.h"
#import "../../Shaders/SharedStructures.h"

NS_ASSUME_NONNULL_BEGIN

@class MGPFrustum;
@interface MGPCameraComponent : MGPSceneNodeComponent

// projection
@property (readonly) matrix_float4x4 projectionMatrix;
@property (readonly) matrix_float4x4 projectionInverseMatrix;
@property MGPProjectionState projectionState;

// camera setup
@property float fStop;
@property float shutterSpeed;
@property NSUInteger ISO;

@property (nonatomic, readonly) MGPFrustum *frustum;
@property (nonatomic, readonly) camera_props_t shaderProperties;

- (float)exposureValue;

@end

NS_ASSUME_NONNULL_END
