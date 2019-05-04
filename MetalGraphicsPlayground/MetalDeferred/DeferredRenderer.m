//
//  DeferredRenderer.m
//  MetalDeferred
//
//  Created by 이현우 on 03/05/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import "DeferredRenderer.h"
#import "../Common/Shaders/SharedStructures.h"
#import "../Common/MGPGBuffer.h"
#import "../Common/MGPMesh.h"
#import "../Common/MetalMath.h"

@implementation DeferredRenderer {
    camera_props_t camera_props;
    instance_props_t instance_props;
    id<MTLBuffer> _cameraPropsBuffer;
    id<MTLBuffer> _instancePropsBuffer;
    
    MGPGBuffer *_gBuffer;
    
    MTLRenderPassDescriptor *_renderPassGBuffer;
    MTLRenderPipelineDescriptor *_baseRenderPipelineDescriptorGBuffer;
    id<MTLRenderPipelineState> _renderPipelineGBuffer;
    MTLRenderPassDescriptor *_renderPassLighting;
    id<MTLRenderPipelineState> _renderPipelineLighting;
    
    NSArray<MGPMesh *> *_meshes;
    MTLVertexDescriptor *_baseVertexDescriptor;
}

- (instancetype)init {
    self = [super init];
    if(self) {
        [self initAssets];
    }
    return self;
}

- (void)initAssets {
    // props
    camera_props.view = matrix_lookat(vector3(0.0f, 25.0f, -60.0f),
                                      vector3(0.0f, 0.0f, 0.0f),
                                      vector3(0.0f, 1.0f, 0.0f));
    camera_props.projection = matrix_from_perspective_fov_aspectLH(45.0f, 1.77778f, 0.01f, 300.0f);
    
    instance_props.model = matrix_identity_float4x4;
    instance_props.material.roughness = 0;
    instance_props.material.metalic = 0;
    
    _cameraPropsBuffer = [self.device newBufferWithLength: sizeof(camera_props_t)
                                                  options: MTLResourceStorageModeManaged];
    memcpy(_cameraPropsBuffer.contents, &camera_props, sizeof(camera_props_t));
    [_cameraPropsBuffer didModifyRange: NSMakeRange(0, sizeof(camera_props_t))];
    _instancePropsBuffer = [self.device newBufferWithLength: sizeof(instance_props_t)
                                                    options: MTLResourceStorageModeManaged];
    memcpy(_instancePropsBuffer.contents, &instance_props, sizeof(instance_props_t));
    [_instancePropsBuffer didModifyRange: NSMakeRange(0, sizeof(instance_props_t))];
    
    // G-buffer
    _gBuffer = [[MGPGBuffer alloc] initWithDevice:self.device
                                             size:CGSizeMake(512,512)];
    
    _renderPassGBuffer = [[_gBuffer renderPassDescriptor] copy];
    _baseRenderPipelineDescriptorGBuffer = [[_gBuffer renderPipelineDescriptor] copy];
    
    _renderPassLighting = [[_gBuffer lightingPassDescriptor] copy];
    
    // vertex descriptor
    _baseVertexDescriptor = [[MTLVertexDescriptor alloc] init];
    _baseVertexDescriptor.attributes[attrib_pos].format = MTLVertexFormatFloat3;
    _baseVertexDescriptor.attributes[attrib_pos].offset = 0;
    _baseVertexDescriptor.attributes[attrib_pos].bufferIndex = 0;
    _baseVertexDescriptor.attributes[attrib_uv].format = MTLVertexFormatFloat2;
    _baseVertexDescriptor.attributes[attrib_uv].offset = 12;
    _baseVertexDescriptor.attributes[attrib_uv].bufferIndex = 0;
    _baseVertexDescriptor.attributes[attrib_normal].format = MTLVertexFormatFloat3;
    _baseVertexDescriptor.attributes[attrib_normal].offset = 20;
    _baseVertexDescriptor.attributes[attrib_normal].bufferIndex = 0;
    _baseVertexDescriptor.attributes[attrib_tangent].format = MTLVertexFormatFloat3;
    _baseVertexDescriptor.attributes[attrib_tangent].offset = 32;
    _baseVertexDescriptor.attributes[attrib_tangent].bufferIndex = 0;
    _baseVertexDescriptor.layouts[0].stride = 44;
    _baseVertexDescriptor.layouts[0].stepRate = 1;
    _baseVertexDescriptor.layouts[0].stepFunction = MTLStepFunctionPerVertex;
    
    MDLVertexDescriptor *mdlVertexDescriptor = MTKModelIOVertexDescriptorFromMetal(_baseVertexDescriptor);
    mdlVertexDescriptor.attributes[attrib_pos].name = MDLVertexAttributePosition;
    mdlVertexDescriptor.attributes[attrib_uv].name = MDLVertexAttributeTextureCoordinate;
    mdlVertexDescriptor.attributes[attrib_normal].name = MDLVertexAttributeNormal;
    mdlVertexDescriptor.attributes[attrib_tangent].name = MDLVertexAttributeTangent;
    
    // meshes
    _meshes = [MGPMesh loadMeshesFromURL: [[NSBundle mainBundle] URLForResource: @"firetruck"
                                                                  withExtension: @"obj"]
                 modelIOVertexDescriptor: mdlVertexDescriptor
                                  device: self.device
                                   error: nil];
    
    // build render pipeline
    MTLFunctionConstantValues *constantValues = [[MTLFunctionConstantValues alloc] init];
    // TODO
    bool hasAlbedoMap = true;
    bool hasNormalMap = true;
    bool hasRoughnessMap = false;
    bool hasMetalicMap = false;
    
    [constantValues setConstantValue: &hasAlbedoMap type: MTLDataTypeBool atIndex: fcv_albedo];
    [constantValues setConstantValue: &hasNormalMap type: MTLDataTypeBool atIndex: fcv_normal];
    [constantValues setConstantValue: &hasRoughnessMap type: MTLDataTypeBool atIndex: fcv_roughness];
    [constantValues setConstantValue: &hasMetalicMap type: MTLDataTypeBool atIndex: fcv_metalic];
    
    _baseRenderPipelineDescriptorGBuffer.vertexDescriptor = _baseVertexDescriptor;
    _baseRenderPipelineDescriptorGBuffer.vertexFunction = [self.defaultLibrary newFunctionWithName: @"gbuffer_vert"
                                                                                    constantValues: constantValues
                                                                                             error: nil];
    _baseRenderPipelineDescriptorGBuffer.fragmentFunction = [self.defaultLibrary newFunctionWithName: @"gbuffer_frag"
                                                                                      constantValues: constantValues
                                                                                               error: nil];
    
    _renderPipelineGBuffer = [self.device newRenderPipelineStateWithDescriptor: _baseRenderPipelineDescriptorGBuffer
                                                                         error: nil];
    
    MTLRenderPipelineDescriptor *renderPipelineDescriptorLighting = [[MTLRenderPipelineDescriptor alloc] init];
    renderPipelineDescriptorLighting.vertexFunction = [self.defaultLibrary newFunctionWithName: @"lighting_vert"];
    renderPipelineDescriptorLighting.fragmentFunction = [self.defaultLibrary newFunctionWithName: @"lighting_frag"];
    renderPipelineDescriptorLighting.label = @"Lighting";
    renderPipelineDescriptorLighting.vertexDescriptor = nil;
}

- (void)update:(float)deltaTime {
}

- (void)render {
    [self beginFrame];
    
    // begin
    id<MTLCommandBuffer> commandBuffer = [self.queue commandBuffer];
    commandBuffer.label = @"Render";
    
    // G-buffer pass
    id<MTLRenderCommandEncoder> gBufferPassEncoder = [commandBuffer renderCommandEncoderWithDescriptor: _gBuffer.renderPassDescriptor];
    [self renderGBuffer:gBufferPassEncoder];
    
    // lighting pass
    id<MTLRenderCommandEncoder> lightingPassEncoder = [commandBuffer renderCommandEncoderWithDescriptor: _gBuffer.renderPassDescriptor];
    [self renderLighting:lightingPassEncoder];
    
    // present
    [commandBuffer presentDrawable: self.view.currentDrawable];
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer) {
        [self endFrame];
    }];
    [commandBuffer commit];
}

- (void)renderGBuffer:(id<MTLRenderCommandEncoder>)encoder {
    encoder.label = @"G-buffer";
    
    [encoder setRenderPipelineState: _renderPipelineGBuffer];
    for(MGPMesh *mesh in _meshes) {
        for(MGPSubmesh *submesh in mesh.submeshes) {
            [encoder setVertexBuffer: mesh.metalKitMesh.vertexBuffers[0].buffer
                              offset: 0
                             atIndex: 0];
            [encoder setVertexBuffer: _cameraPropsBuffer
                              offset: 0
                             atIndex: 1];
            [encoder setVertexBuffer: _instancePropsBuffer
                              offset: 0
                             atIndex: 2];
            
            [encoder setFragmentTexture: submesh.textures[tex_albedo] atIndex: tex_albedo];
            [encoder setFragmentTexture: submesh.textures[tex_normal] atIndex: tex_normal];
            [encoder setFragmentBuffer: _cameraPropsBuffer
                                offset: 0
                               atIndex: 1];
            [encoder setFragmentBuffer: _instancePropsBuffer
                                offset: 0
                               atIndex: 2];
            
            [encoder drawIndexedPrimitives: submesh.metalKitSubmesh.primitiveType
                                indexCount: submesh.metalKitSubmesh.indexCount
                                 indexType: submesh.metalKitSubmesh.indexType
                               indexBuffer: submesh.metalKitSubmesh.indexBuffer.buffer
                         indexBufferOffset: submesh.metalKitSubmesh.indexBuffer.offset];
        }
    }
    
    [encoder endEncoding];
}

- (void)renderLighting:(id<MTLRenderCommandEncoder>)encoder {
    encoder.label = @"Lighting";
    
    // TODO
    
    [encoder endEncoding];
}

- (void)resize:(CGSize)newSize {
    [_gBuffer resize:newSize];
}

@end
