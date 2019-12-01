//
//  MGPSceneRenderer.m
//  MetalGraphicsPlayground
//
//  Created by 이현우 on 2019/10/07.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import "MGPSceneRenderer.h"
#import "../Model/MGPScene.h"
#import "../Model/MGPSceneNode.h"
#import "../Model/MGPSceneNodeComponent.h"
#import "../Model/MGPCameraComponent.h"
#import "../Model/MGPLightComponent.h"
#import "../Model/MGPMeshComponent.h"
#import "../Model/MGPMesh.h"
#import "../Model/MGPFrustum.h"
#import "../Model/MGPBoundingVolume.h"

@interface MGPDrawCall ()
@property (nonatomic) MGPMesh *mesh;
@property (nonatomic, readwrite) NSUInteger instanceCount;
@property (nonatomic, readwrite) id<MTLBuffer> instancePropsBuffer;
@property (nonatomic, readwrite) NSUInteger instancePropsBufferOffset;
@end

@implementation MGPDrawCall
@end

@interface MGPDrawCallList ()
- (instancetype)initWithFrustum: (MGPFrustum *)frustum
                      drawCalls: (NSArray<MGPDrawCall*> *)drawCalls;
@end

@implementation MGPDrawCallList

- (instancetype)initWithFrustum:(MGPFrustum *)frustum drawCalls:(NSArray<MGPDrawCall *> *)drawCalls {
    self = [super init];
    if(self) {
        _frustum = frustum;
        _drawCalls = [NSArray arrayWithArray:drawCalls];
    }
    return self;
}

@end

@interface MGPSceneRenderer ()
@end

@implementation MGPSceneRenderer {
    id<MTLDevice> _device;
    NSMutableArray<id<MTLHeap>> *_instanceBufferHeaps;
    NSUInteger _instancePropsHeapIndex;
    NSUInteger _instancePropsHeapOffset;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device {
    self = [super init];
    if(self) {
        _device = device;
        _instanceBufferHeaps = [NSMutableArray new];
        
        // make temporary buffers
        _cameraComponents = [NSMutableArray new];
        _lightComponents = [NSMutableArray new];
        _meshComponents = [NSMutableArray new];
    }
    return self;
}

- (void)beginFrame {
    [super beginFrame];
    
    // collects cameras, lights, meshes...
    NSMutableArray *nodes = [NSMutableArray new];
    [nodes addObject: _scene.rootNode];
    while(nodes.count > 0) {
        MGPSceneNode *node = [nodes lastObject];
        [nodes removeLastObject];
        
        for(MGPSceneNodeComponent *comp in node.components) {
            if([comp isKindOfClass:MGPCameraComponent.class])
               [_cameraComponents addObject:(MGPCameraComponent*)comp];
            else if([comp isKindOfClass:MGPLightComponent.class])
                [_lightComponents addObject:(MGPLightComponent*)comp];
            else if([comp isKindOfClass:MGPMeshComponent.class])
                [_meshComponents addObject:(MGPMeshComponent*)comp];
        }
        
        [nodes addObjectsFromArray:node.children];
    }
    
    // initialize heap index and offset...
    _instancePropsHeapIndex = 0;
    _instancePropsHeapOffset = 0;
}

- (void)endFrame {
    [super endFrame];
    
    [_cameraComponents removeAllObjects];
    [_lightComponents removeAllObjects];
    [_meshComponents removeAllObjects];
}

- (id<MTLBuffer>)makeInstancePropsBufferWithInstanceCount: (NSUInteger)instanceCount {
    id<MTLBuffer> buffer = nil;
    NSUInteger instancePropsSize = sizeof(instance_props_t) * instanceCount;
    
    while(!buffer) {
        BOOL newHeap = NO;
        if(_instanceBufferHeaps.count <= _instancePropsHeapIndex) {
            newHeap = YES;
        }
        else {
            id<MTLHeap> heap = _instanceBufferHeaps[_instancePropsHeapIndex];
            if(instancePropsSize + heap.usedSize > heap.size) {
                _instancePropsHeapIndex += 1;
                _instancePropsHeapOffset = 0;
                newHeap = YES;
            }
            else {
                buffer = [heap newBufferWithLength:instancePropsSize
                                           options:MTLResourceStorageModeManaged];
                if(buffer == nil)
                    break;
                else
                    _instancePropsHeapOffset += instancePropsSize;
            }
        }
        
        if(newHeap) {
            // make new heap for instance props buffer
            MTLHeapDescriptor *heapDesc = [MTLHeapDescriptor new];
            heapDesc.size = MAX(1024*1024, instancePropsSize);  // minimum 1MB
            heapDesc.storageMode = MTLStorageModeManaged;
            id<MTLHeap> heap = [_device newHeapWithDescriptor:heapDesc];
            if(heap)
                [_instanceBufferHeaps addObject:heap];
            else
                break;
        }
    }
    
    return buffer;
}

- (MGPDrawCallList *)drawCallListWithFrustum:(MGPFrustum *)frustum {
    NSMutableArray<MGPDrawCall*> *drawCalls = [NSMutableArray new];
    NSMutableArray<MGPDrawCall*> *combinedDrawCalls = [NSMutableArray new];
    
    // Collect draw calls from mesh components...
    for(MGPMeshComponent *meshComponent in _meshComponents) {
        MGPMesh *mesh = meshComponent.mesh;
        if(mesh == nil)
            continue;
        
        // Check all submeshes' bounding volumes...
        for(MGPSubmesh *submesh in mesh.submeshes) {
            id<MGPBoundingVolume> volume = submesh.volume;
            if([volume isCulledInFrustum: frustum])
                continue;
        }
        
        MGPDrawCall *drawCall = [MGPDrawCall new];
        drawCall.mesh = mesh;
        drawCall.instanceCount = 1;
        [drawCalls addObject: drawCall];
    }
    
    // Sort draw calls by mesh
    [drawCalls sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        size_t ptr1 = (size_t)obj1;
        size_t ptr2 = (size_t)obj2;
        return (ptr1 == ptr2) ? 0 : ((ptr1 < ptr2) ? -1 : 1);
    }];
    
    // Combine draw calls
    MGPMesh *prevMesh = nil;
    MGPDrawCall *prevDrawCall = nil;
    for(MGPDrawCall *drawCall in drawCalls) {
        if(prevMesh != drawCall.mesh) {
            if(prevDrawCall.instanceCount) {
                prevDrawCall.instancePropsBuffer = [self makeInstancePropsBufferWithInstanceCount:prevDrawCall.instanceCount];
            }
            
            prevMesh = drawCall.mesh;
            prevDrawCall = [MGPDrawCall new];
            prevDrawCall.mesh = prevMesh;
            prevDrawCall.instanceCount = 1;
            [combinedDrawCalls addObject: prevDrawCall];
        }
        else {
            prevDrawCall.instanceCount += 1;
        }
    }
    if(prevDrawCall.instanceCount && prevDrawCall.instancePropsBuffer == nil) {
        prevDrawCall.instancePropsBuffer = [self makeInstancePropsBufferWithInstanceCount:prevDrawCall.instanceCount];
    }
    
    MGPDrawCallList *drawCallList = [[MGPDrawCallList alloc] initWithFrustum: frustum
                                                                   drawCalls: drawCalls];
    return drawCallList;
}

@end
