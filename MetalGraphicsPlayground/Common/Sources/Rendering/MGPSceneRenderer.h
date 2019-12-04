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
@class MGPCameraComponent;
@class MGPLightComponent;
@class MGPMeshComponent;

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
@interface MGPSceneRenderer : MGPRenderer {
    @protected
    NSMutableArray<MGPCameraComponent*> *_cameraComponents;
    NSMutableArray<MGPLightComponent*> *_lightComponents;
    NSMutableArray<MGPMeshComponent*> *_meshComponents;
    
    id<MTLBuffer> _cameraPropsBuffer;
    id<MTLBuffer> _lightPropsBuffer;
    id<MTLBuffer> _lightGlobalBuffer;
    
    // Profiling
    float _CPUTime;
    float _GPUTime;
}

@property (nonatomic) MGPScene *scene;

- (MGPDrawCallList *)drawCallListWithFrustum: (MGPFrustum *)frustum;

@end

NS_ASSUME_NONNULL_END
