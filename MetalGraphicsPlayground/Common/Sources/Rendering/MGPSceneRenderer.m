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
#import "LightingCommon.h"

@interface MGPDrawCall ()
@property (nonatomic) MGPMesh *mesh;
@property (nonatomic, readwrite) NSUInteger instanceCount;
@property (nonatomic, readwrite) id<MTLBuffer> instancePropsBuffer;
@property (nonatomic, readwrite) NSUInteger instancePropsBufferOffset;
@property (nonatomic, readwrite) instance_props_t instanceProps;
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
    NSMutableArray<id<MTLBuffer>> *_instancePropsBuffersList[kMaxBuffersInFlight];
    NSUInteger _instancePropsBufferIndex;
    NSUInteger _instancePropsBufferOffset;
}

- (instancetype)init {
    self = [super init];
    if(self) {
        // GPU-buffer
        for(NSUInteger i = 0; i < kMaxBuffersInFlight; i++) {
            _instancePropsBuffersList[i] = [NSMutableArray new];
        }
        _lightGlobalBuffer = [self.device newBufferWithLength:sizeof(light_global_t)*kMaxBuffersInFlight
                                                      options:MTLResourceStorageModeManaged];
        _lightPropsBuffer = [self.device newBufferWithLength:sizeof(light_t)*kMaxBuffersInFlight*MAX_NUM_LIGHTS
                                                      options:MTLResourceStorageModeManaged];
        _cameraPropsBuffer = [self.device newBufferWithLength:sizeof(camera_props_t)*kMaxBuffersInFlight * MAX_NUM_CAMS
                                                      options:MTLResourceStorageModeManaged];
        
        // make temporary buffers
        _cameraComponents = [NSMutableArray new];
        _lightComponents = [NSMutableArray new];
        _meshComponents = [NSMutableArray new];
    }
    return self;
}

- (void)resize:(CGSize)newSize {
    _size = newSize;
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
    
    // sort lights by light type
    [_lightComponents sortUsingComparator:
     ^NSComparisonResult(MGPLightComponent* _Nonnull obj1, MGPLightComponent*  _Nonnull obj2) {
        if(obj1.type < obj2.type)
            return NSOrderedAscending;
        else if(obj1.type > obj2.type)
            return NSOrderedDescending;
        return NSOrderedSame;
    }];
    
    // find first point light index
    NSUInteger numLights = MIN(MAX_NUM_LIGHTS, _lightComponents.count);
    NSUInteger firstPointLightIndex = 0;
    for(NSUInteger i = 0; i < numLights; i++) {
        if(_lightComponents[i].type == MGPLightTypeDirectional) {
            firstPointLightIndex++;
        }
        else {
            break;
        }
    }
    
    // initialize heap index and offset...
    _instancePropsBufferIndex = 0;
    _instancePropsBufferOffset = 0;
    
    // sort instance props buffers by size
    [_instancePropsBuffersList[_currentBufferIndex] sortUsingComparator:
     ^NSComparisonResult(id<MTLBuffer> b1, id<MTLBuffer> b2) {
        if(b1.length > b2.length)
            return NSOrderedAscending;
        else if(b1.length < b2.length)
            return NSOrderedDescending;
        return NSOrderedSame;
    }];
    
    // update light global buffer...
    light_global_t lightGlobalProps = _scene.lightGlobalProps;
    lightGlobalProps.num_light = (unsigned int)numLights;
    lightGlobalProps.first_point_light_index = (unsigned int)firstPointLightIndex;
    _scene.lightGlobalProps = lightGlobalProps;
    memcpy(_lightGlobalBuffer.contents + _currentBufferIndex * sizeof(light_global_t), &lightGlobalProps, sizeof(light_global_t));
    [_lightGlobalBuffer didModifyRange: NSMakeRange(_currentBufferIndex * sizeof(light_global_t),
                                                    sizeof(light_global_t))];
    
    // update light buffer...
    size_t lightPropsBufferOffset = _currentBufferIndex * sizeof(light_t) * MAX_NUM_LIGHTS;
    for(NSUInteger i = 0; i < numLights; i++) {
        light_t lightProps = _lightComponents[i].shaderProperties;
        memcpy(_lightPropsBuffer.contents + lightPropsBufferOffset, &lightProps, sizeof(light_t));
        lightPropsBufferOffset += sizeof(light_t);
    }
    [_lightPropsBuffer didModifyRange: NSMakeRange(_currentBufferIndex * sizeof(light_t) * MAX_NUM_LIGHTS,
                                                    sizeof(light_t) * numLights)];
    
    // update camera buffer...
    size_t cameraPropsBufferOffset = _currentBufferIndex * sizeof(camera_props_t) * MAX_NUM_CAMS;
    for(NSUInteger i = 0; i < MIN(4, _cameraComponents.count); i++) {
        _cameraComponents[i].aspectRatio = _size.width / MAX(0.01f, _size.height);
        camera_props_t cameraProps = _cameraComponents[i].shaderProperties;
        memcpy(_cameraPropsBuffer.contents + cameraPropsBufferOffset, &cameraProps, sizeof(camera_props_t));
        cameraPropsBufferOffset += sizeof(camera_props_t);
    }
    [_cameraPropsBuffer didModifyRange: NSMakeRange(_currentBufferIndex * sizeof(camera_props_t) * MAX_NUM_CAMS,
                                                    sizeof(camera_props_t) * MIN(4, _cameraComponents.count))];
}

- (void)endFrame {
    [super endFrame];
    
    [_cameraComponents removeAllObjects];
    [_lightComponents removeAllObjects];
    [_meshComponents removeAllObjects];
}

- (id<MTLBuffer>)makeInstancePropsBufferWithInstanceCount:(NSUInteger)instanceCount
                                                   offset:(NSUInteger*)offset {
    id<MTLBuffer> buffer = nil;
    NSUInteger instancePropsSize = sizeof(instance_props_t) * instanceCount;
    
    NSMutableArray<id<MTLBuffer>> *instancePropsBuffers = _instancePropsBuffersList[_currentBufferIndex];
    BOOL newBuffer = NO;
    for(; _instancePropsBufferIndex < instancePropsBuffers.count; _instancePropsBufferIndex++) {
        buffer = instancePropsBuffers[_instancePropsBufferIndex];
        if(instancePropsSize + _instancePropsBufferOffset > buffer.length) {
            _instancePropsBufferIndex += 1;
            _instancePropsBufferOffset = 0;
            buffer = nil;
        }
        else {
            if(offset)
                *offset = _instancePropsBufferOffset;
            _instancePropsBufferOffset += instancePropsSize;
            break;
        }
    }
    if(buffer == nil) {
        newBuffer = YES;
    }
    
    if(newBuffer) {
        // make new heap for instance props buffer
        buffer = [self.device newBufferWithLength:MAX(instancePropsSize, sizeof(instance_props_t) * 64)
                                          options:MTLResourceStorageModeManaged];
        if(buffer) {
            [instancePropsBuffers addObject:buffer];
            if(offset)
                *offset = 0;
            _instancePropsBufferOffset = instancePropsSize;
        }
        else {
            NSLog(@"Failed to create new instance props buffer.");
        }
    }
    
    return buffer;
}

- (MGPDrawCallList *)drawCallListWithFrustum:(MGPFrustum *)frustum {
    NSMutableArray<MGPDrawCall*> *combinedDrawCalls = [NSMutableArray new];
    
    NSMutableDictionary<NSNumber*,MGPMesh*> *meshDict = [NSMutableDictionary dictionary];
    NSMutableDictionary<NSNumber*,NSMutableArray<MGPMeshComponent*>*> *compListDict = [NSMutableDictionary dictionary];
    
    // collect mesh component list by mesh
    for(MGPMeshComponent *meshComponent in _meshComponents) {
        MGPMesh *mesh = meshComponent.mesh;
        if(mesh == nil)
            continue;
        
        // Check mesh bounding volumes...
        id<MGPBoundingVolume> volume = mesh.volume;
        if([volume isCulledInFrustum:frustum])
            continue;
        
        NSNumber *key = @((size_t)mesh);
        if(![meshDict objectForKey:key])
            meshDict[key] = mesh;
        NSMutableArray<MGPMeshComponent*> *list = [compListDict objectForKey:key];
        if(!list) {
            list = [NSMutableArray array];
            compListDict[key] = list;
        }
        [list addObject:meshComponent];
    }
    
    // Combine draw calls
    for(NSNumber *key in compListDict) {
        MGPMesh *mesh = meshDict[key];
        NSMutableArray<MGPMeshComponent*> *list = compListDict[key];
        for(NSUInteger i = 0; i < list.count; i += MAX_NUM_INSTANCE) {
            MGPDrawCall *drawCall = [MGPDrawCall new];
            drawCall.mesh = mesh;
            drawCall.instanceCount = MIN(MAX_NUM_INSTANCE, list.count - i);
            NSUInteger instancePropsBufferOffset = 0;
            drawCall.instancePropsBuffer = [self makeInstancePropsBufferWithInstanceCount:drawCall.instanceCount
                                                                                   offset:&instancePropsBufferOffset];
            drawCall.instancePropsBufferOffset = instancePropsBufferOffset;

            // fill instance props into buffer
            instance_props_t *contents = (instance_props_t *)(drawCall.instancePropsBuffer.contents + instancePropsBufferOffset);
            for(NSUInteger j = 0, k = i; j < drawCall.instanceCount; j++) {
                contents[j] = list[k++].instanceProps;
            }
            [drawCall.instancePropsBuffer didModifyRange:NSMakeRange(drawCall.instancePropsBufferOffset, sizeof(instance_props_t) * drawCall.instanceCount)];
            [combinedDrawCalls addObject:drawCall];
        }
    }
    
    MGPDrawCallList *drawCallList = [[MGPDrawCallList alloc] initWithFrustum: frustum
                                                                   drawCalls: combinedDrawCalls];
    return drawCallList;
}

@end
