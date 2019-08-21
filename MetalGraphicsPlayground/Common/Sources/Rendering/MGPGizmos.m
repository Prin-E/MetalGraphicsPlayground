//
//  MGPGizmos.m
//  MetalGraphicsPlayground
//
//  Created by 이현우 on 2019/08/20.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import "MGPGizmos.h"
#import "../../Shaders/SharedStructures.h"
@import MetalKit;
@import ModelIO;

@implementation MGPGizmos {
    id<MTLDevice> _device;
    id<MTLLibrary> _library;
    
    NSUInteger _numberOfGizmos;
    NSUInteger _maxBuffersInFlight;
    NSUInteger _currentGizmoIndex;
    NSMutableArray<id<MTLBuffer>> *_propsBuffers;
    
    MTKMesh *_sphereMesh;
    id<MTLBuffer> _cameraPropsBuffer;
    
    MTLRenderPipelineDescriptor *_wireframePipelineDesc;
    id<MTLRenderPipelineState> _wireframePipeline;
    MTLRenderPassDescriptor *_wireframePass;
    id<MTLDepthStencilState> _depthStencil;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
                       library:(id<MTLLibrary>)library
                 gizmoCapacity:(NSUInteger)capacity
             maxBuffersInFight:(NSUInteger)inFlight {
    self = [super init];
    if(self) {
        _device = device;
        _library = library;
        _numberOfGizmos = capacity;
        _maxBuffersInFlight = inFlight;
        [self _makePrimitives];
        [self _makeRenderPipeline];
        [self _makeRenderPass];
        [self _makePropsBuffers];
        [self _makeDepthStencil];
    }
    return self;
}

- (void)_makePrimitives {
    MTKMeshBufferAllocator *allocator = [[MTKMeshBufferAllocator alloc] initWithDevice:_device];
    MDLMesh *mdlSphere = [MDLMesh newEllipsoidWithRadii:simd_make_float3(0.5f, 0.5f, 0.5f)
                                         radialSegments:12
                                       verticalSegments:12
                                           geometryType:MDLGeometryTypeTriangles
                                          inwardNormals:NO
                                             hemisphere:NO
                                              allocator:allocator];
    _sphereMesh = [[MTKMesh alloc] initWithMesh:mdlSphere
                                         device:_device
                                          error:nil];
}

- (void)_makeRenderPipeline {
    MTLRenderPipelineDescriptor *desc = [MTLRenderPipelineDescriptor new];
    desc.colorAttachments[0].blendingEnabled = YES;
    desc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
    desc.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    desc.vertexFunction = [_library newFunctionWithName:@"gizmo_wireframe_vert"];
    desc.fragmentFunction = [_library newFunctionWithName:@"gizmo_wireframe_frag"];
    desc.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(_sphereMesh.vertexDescriptor);
    desc.sampleCount = 1;
    _wireframePipelineDesc = desc;
}

- (void)_makeRenderPass {
    _wireframePass = [[MTLRenderPassDescriptor alloc] init];
    _wireframePass.colorAttachments[0].loadAction = MTLLoadActionLoad;
    _wireframePass.colorAttachments[0].storeAction = MTLStoreActionStore;
    _wireframePass.depthAttachment.loadAction = MTLLoadActionLoad;
    _wireframePass.depthAttachment.storeAction = MTLStoreActionDontCare;
}

- (void)_makePropsBuffers {
    _propsBuffers = [NSMutableArray arrayWithCapacity:_maxBuffersInFlight];
    for(NSUInteger i = 0; i < _maxBuffersInFlight; i++) {
        id<MTLBuffer> buffer = [_device newBufferWithLength:sizeof(gizmo_props_t)*_numberOfGizmos
                                                    options:MTLResourceStorageModeManaged];
        [_propsBuffers addObject:buffer];
    }
}

- (void)_makeDepthStencil {
    MTLDepthStencilDescriptor *desc = [MTLDepthStencilDescriptor new];
    desc.depthCompareFunction = MTLCompareFunctionLess;
    desc.depthWriteEnabled = NO;
    _depthStencil = [_device newDepthStencilStateWithDescriptor:desc];
}

- (void)drawWireframeSphereWithCenter:(simd_float3)position
                               radius:(float)radius {
    id<MTLBuffer> buffer = _propsBuffers[_currentBufferIndex];
    if(buffer.length <= _currentGizmoIndex * sizeof(gizmo_props_t)) {
        id<MTLBuffer> newBuffer = [_device newBufferWithLength:buffer.length*2
                                                       options:MTLResourceStorageModeManaged];
        memcpy(newBuffer.contents, buffer.contents, buffer.length);
        _propsBuffers[_currentBufferIndex] = newBuffer;
        buffer = newBuffer;
    }
    gizmo_props_t gizmo = {
        .position = position,
        .color = simd_make_float4(0, 0, 1, 1),
        .radius = radius
    };
    memcpy(buffer.contents + sizeof(gizmo_props_t) * _currentGizmoIndex,
           &gizmo,
           sizeof(gizmo_props_t));
    _currentGizmoIndex++;
}

- (void)prepareEncodingWithColorTexture:(id<MTLTexture>)colorTex
                           depthTexture:(id<MTLTexture>)depthTex
                           cameraBuffer:(id<MTLBuffer>)cameraBuffer
                            bufferIndex:(NSUInteger)bufferIndex {
    _currentGizmoIndex = 0;
    _cameraPropsBuffer = cameraBuffer;
    _wireframePass.colorAttachments[0].texture = colorTex;
    _wireframePass.depthAttachment.texture = depthTex;
    _currentBufferIndex = bufferIndex;
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)buffer {
    if(_wireframePass.colorAttachments[0].texture == nil) {
        @throw [NSException exceptionWithName: @"MGPGizmosExceptionDomain"
                                       reason: @"render pass has not queried."
                                     userInfo: @{}];
    }
    
    if(_wireframePipeline == nil ||
       _wireframePipelineDesc.colorAttachments[0].pixelFormat != _wireframePass.colorAttachments[0].texture.pixelFormat ||
       _wireframePipelineDesc.depthAttachmentPixelFormat != _wireframePass.depthAttachment.texture.pixelFormat) {
        _wireframePipelineDesc.colorAttachments[0].pixelFormat = _wireframePass.colorAttachments[0].texture.pixelFormat;
        _wireframePipelineDesc.depthAttachmentPixelFormat = _wireframePass.depthAttachment.texture != nil ? _wireframePass.depthAttachment.texture.pixelFormat : MTLPixelFormatInvalid;
        _wireframePipeline = [_device newRenderPipelineStateWithDescriptor:_wireframePipelineDesc
                                                                     error:nil];
    }
    
    if(_currentGizmoIndex > 0) {
        [_propsBuffers[_currentBufferIndex] didModifyRange:NSMakeRange(0, _currentGizmoIndex*sizeof(gizmo_props_t))];
        
        id<MTLRenderCommandEncoder> encoder = [buffer renderCommandEncoderWithDescriptor:_wireframePass];
        [encoder setRenderPipelineState:_wireframePipeline];
        [encoder setTriangleFillMode:MTLTriangleFillModeLines];
        [encoder setDepthStencilState:_depthStencil];
        [encoder setCullMode:MTLCullModeBack];
        [encoder setVertexBuffer:_sphereMesh.vertexBuffers[0].buffer
                          offset:_sphereMesh.vertexBuffers[0].offset
                         atIndex:0];
        [encoder setVertexBuffer:_cameraPropsBuffer
                          offset:sizeof(camera_props_t)*_currentBufferIndex
                         atIndex:1];
        [encoder setVertexBuffer:_propsBuffers[_currentBufferIndex]
                          offset:0
                         atIndex:2];
        for(MTKSubmesh *submesh in _sphereMesh.submeshes) {
            [encoder drawIndexedPrimitives:submesh.primitiveType
                                indexCount:submesh.indexCount
                                 indexType:submesh.indexType
                               indexBuffer:submesh.indexBuffer.buffer
                         indexBufferOffset:submesh.indexBuffer.offset
                             instanceCount:_currentGizmoIndex];
        }
        [encoder endEncoding];
    }
}

- (MTLRenderPassDescriptor *)wireframeRenderPassWithColorAttachment:(id<MTLTexture>)colorTex
                                                    depthAttachment:(id<MTLTexture>)depthTex {
    _wireframePass.colorAttachments[0].texture = colorTex;
    _wireframePass.depthAttachment.texture = depthTex;
    return _wireframePass;
}

@end
