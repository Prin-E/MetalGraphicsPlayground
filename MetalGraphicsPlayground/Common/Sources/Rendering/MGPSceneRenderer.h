//
//  MGPSceneRenderer.h
//  MetalGraphicsPlayground
//
//  Created by 이현우 on 2019/10/07.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import "MGPRenderer.h"
#import "SharedStructures.h"
@import Metal;

NS_ASSUME_NONNULL_BEGIN

@class MGPScene;
@class MGPFrustum;
@class MGPMesh;
@class MGPLight;

@interface MGPDrawCall : NSObject

@property (nonatomic, readonly) MGPMesh *mesh;
@property (nonatomic, readonly) NSUInteger instanceCount;
@property (nonatomic, readonly) id<MTLBuffer> instancePropsBuffer;
@property (nonatomic, readonly) NSUInteger instancePropsBufferOffset;

@end

@interface MGPDrawCallList : NSObject

@property (nonatomic, readonly) MGPFrustum *frustum;
@property (nonatomic, readonly) NSArray<MGPDrawCall*> *drawCalls;

@end

// The scene renderer base class.
@interface MGPSceneRenderer : MGPRenderer

@property (nonatomic) MGPScene *scene;

- (instancetype)initWithDevice: (id<MTLDevice>)device;

- (void)beginRendering;
- (void)finishRendering;

- (MGPDrawCallList *)drawCallListWithFrustum: (MGPFrustum *)frustum;

@end

NS_ASSUME_NONNULL_END
