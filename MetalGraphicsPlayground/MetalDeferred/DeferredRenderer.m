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

#define TEST 1

const size_t kMaxBuffersInFlight = 3;
const size_t kNumInstance = 8;
const uint32_t kNumLight = 32;

#define DEG_TO_RAD(x) ((x)*0.0174532925)

@implementation DeferredRenderer {
    camera_props_t camera_props[kMaxBuffersInFlight];
    instance_props_t instance_props[kMaxBuffersInFlight * kNumInstance];
    light_t light_props[kMaxBuffersInFlight * kNumLight];
    
    size_t _currentBufferIndex;
    float _elapsedTime;
    bool _animate;
    float _animationTime;
    
    // props
    id<MTLBuffer> _cameraPropsBuffer;
    id<MTLBuffer> _instancePropsBuffer;
    id<MTLBuffer> _lightPropsBuffer;
    id<MTLBuffer> _lightGlobalBuffer;
    
    // quad vertex buffer
    id<MTLBuffer> _quadVertexBuffer;
    
    // g-buffer
    MGPGBuffer *_gBuffer;
    
    // render pass, pipeline states
    MTLRenderPassDescriptor *_renderPassGBuffer;
    MTLRenderPipelineDescriptor *_baseRenderPipelineDescriptorGBuffer;
    id<MTLRenderPipelineState> _renderPipelineGBuffer;
    MTLRenderPassDescriptor *_renderPassLighting;
    id<MTLRenderPipelineState> _renderPipelineLighting;
    
    // depth-stencil
    id<MTLDepthStencilState> _depthStencil;
    
    NSArray<MGPMesh *> *_meshes;
    MTLVertexDescriptor *_baseVertexDescriptor;
    
    MTKMesh *_sphereMesh;
}

- (void)setView:(MGPView *)view {
    [super setView:view];
    [view setDelegate:self];
}

- (void)view:(MGPView *)view keyDown:(NSEvent *)theEvent {
    if(theEvent.keyCode == 49) {
        _animate = !_animate;
    }
}

- (instancetype)init {
    self = [super init];
    if(self) {
        _animate = YES;
        [self initUniformBuffers];
        [self initAssets];
    }
    return self;
}

- (void)initUniformBuffers {
    // props
    _cameraPropsBuffer = [self.device newBufferWithLength: sizeof(camera_props)
                                                  options: MTLResourceStorageModeManaged];
    _instancePropsBuffer = [self.device newBufferWithLength: sizeof(instance_props)
                                                    options: MTLResourceStorageModeManaged];
    _lightPropsBuffer = [self.device newBufferWithLength: sizeof(light_props)
                                                 options: MTLResourceStorageModeManaged];
    _lightGlobalBuffer = [self.device newBufferWithBytes: &kNumLight
                                                  length: sizeof(light_global_t)
                                                 options: MTLResourceStorageModeManaged];
}

- (void)initAssets {
    // quad vertex
    static const simd_float3 QuadVertices[] =
    {
        { -1.0f, -1.0f, 0.0f },
        { -1.0f, 1.0f, 0.0f },
        { 1.0f, -1.0f, 0.0f },
        { 1.0f, -1.0f, 0.0f },
        { -1.0f, 1.0f, 0.0f },
        { 1.0f, 1.0f, 0.0f }
    };
    
    _quadVertexBuffer = [self.device newBufferWithBytes:QuadVertices
                                                 length:sizeof(QuadVertices)
                                                options:0];
    
    
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
    _baseVertexDescriptor.attributes[attrib_bitangent].format = MTLVertexFormatFloat3;
    _baseVertexDescriptor.attributes[attrib_bitangent].offset = 44;
    _baseVertexDescriptor.attributes[attrib_bitangent].bufferIndex = 0;
    _baseVertexDescriptor.layouts[0].stride = 56;
    _baseVertexDescriptor.layouts[0].stepRate = 1;
    _baseVertexDescriptor.layouts[0].stepFunction = MTLStepFunctionPerVertex;
    
    MDLVertexDescriptor *mdlVertexDescriptor = MTKModelIOVertexDescriptorFromMetal(_baseVertexDescriptor);
    mdlVertexDescriptor.attributes[attrib_pos].name = MDLVertexAttributePosition;
    mdlVertexDescriptor.attributes[attrib_uv].name = MDLVertexAttributeTextureCoordinate;
    mdlVertexDescriptor.attributes[attrib_normal].name = MDLVertexAttributeNormal;
    mdlVertexDescriptor.attributes[attrib_tangent].name = MDLVertexAttributeTangent;
    mdlVertexDescriptor.attributes[attrib_bitangent].name = MDLVertexAttributeBitangent;
    
    // meshes
    _meshes = [MGPMesh loadMeshesFromURL: [[NSBundle mainBundle] URLForResource: @"firetruck"
                                                                  withExtension: @"obj"]
                 modelIOVertexDescriptor: mdlVertexDescriptor
                                  device: self.device
                                   error: nil];
    
    MDLMesh *mdlMesh = [MDLMesh newEllipsoidWithRadii: vector3(10.0f, 10.0f, 10.0f)
                                       radialSegments: 32
                                     verticalSegments: 32
                                         geometryType: MDLGeometryTypeTriangles
                                        inwardNormals: NO
                                           hemisphere: NO
                                            allocator: [[MTKMeshBufferAllocator alloc] initWithDevice: self.device]];
    mdlMesh.vertexDescriptor = mdlVertexDescriptor;
    _sphereMesh = [[MTKMesh alloc] initWithMesh:mdlMesh
                                         device:self.device
                                          error:nil];
    
    // build render pipeline
    MTLFunctionConstantValues *constantValues = [[MTLFunctionConstantValues alloc] init];
    // TODO
#if !TEST
    BOOL hasAlbedoMap = YES;
    BOOL hasNormalMap = YES;
    BOOL hasRoughnessMap = YES;
    BOOL hasMetalicMap = YES;
#else
    BOOL hasAlbedoMap = NO;
    BOOL hasNormalMap = NO;
    BOOL hasRoughnessMap = NO;
    BOOL hasMetalicMap = NO;
#endif
    
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
    renderPipelineDescriptorLighting.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm_sRGB;
    
    _renderPipelineLighting = [self.device newRenderPipelineStateWithDescriptor: renderPipelineDescriptorLighting
                                                                          error: nil];
    
    // depth-stencil
    MTLDepthStencilDescriptor *depthStencilDescriptor = [[MTLDepthStencilDescriptor alloc] init];
    depthStencilDescriptor.depthWriteEnabled = YES;
    depthStencilDescriptor.depthCompareFunction = MTLCompareFunctionLess;
    _depthStencil = [self.device newDepthStencilStateWithDescriptor: depthStencilDescriptor];
}

- (void)update:(float)deltaTime {
    [self updateUniformBuffers: deltaTime];
}

- (void)updateUniformBuffers: (float)deltaTime {
    // Update camera properties
    camera_props[_currentBufferIndex].view = matrix_lookat(vector3(0.0f, 20.0f, -60.0f),
                                                           vector3(0.0f, 2.5f, 0.0f),
                                                           vector3(0.0f, 1.0f, 0.0f));
    camera_props[_currentBufferIndex].projection = matrix_from_perspective_fov_aspectLH(DEG_TO_RAD(60.0f), _gBuffer.size.width / _gBuffer.size.height, 0.5f, 150.0f);
    
    // Update per-instance properties
    static const simd_float3 instance_pos[] = {
        { 0, 0, 0 },
        { 30, 0, 30 },
        { 30, 0, -30 },
        { -30, 0, 30 },
        { -30, 0, -30 },
        { 60, 0, 0 },
        { -60, 0, 0 },
        { 0, 0, 60 }
    };
    for(NSInteger i = 0; i < kNumInstance; i++) {
        instance_props_t *p = &instance_props[_currentBufferIndex * kNumInstance + i];
        p->model = matrix_multiply(matrix_from_translation(instance_pos[i].x, instance_pos[i].y, instance_pos[i].z), matrix_from_rotation(_animationTime, 0, 1, 0));
        p->modelView = matrix_multiply(camera_props[_currentBufferIndex].view, p->model);
        p->material.roughness = self.roughness;
        p->material.metalic = self.metalic;
    }
    
    // Update lights
    static simd_float3 light_colors[kNumLight];
    static float light_intensities[kNumLight];
    static simd_float4 light_dirs[kNumLight];
    static BOOL init_light_value = NO;
    if(!init_light_value) {
        init_light_value = YES;
        for(int i = 0; i < kNumLight; i++) {
            light_colors[i] = vector3(rand() / (float)RAND_MAX, rand() / (float)RAND_MAX, rand() / (float)RAND_MAX);
            light_intensities[i] = 0.1f + rand() / (float)RAND_MAX * 0.5f;
            light_dirs[i] = simd_normalize(vector4(rand() / (float)RAND_MAX - 0.5f, rand() / (float)RAND_MAX - 0.5f,
                                                   rand() / (float)RAND_MAX - 0.5f, 0.0f));
        }
    }
    /*
    static const simd_float3 light_colors[] = {
        { 0.4, 0.8, 1 },
        { 0.1, 0.8, 0.4 },
        { 1.0, 1.0, 1.0 }
    };
    static const float light_intensities[] = {
        1.5, 0.8, 1.0
    };
    static const simd_float4 light_dirs[] = {
        { -1.0, -1.0, 1.0, 0.0 },
        { 1.0, 1.0, 1.0, 0.0 },
        { -1.0, 0.0, 0.0, 0.0 }
    };
    */
    for(NSInteger i = 0; i < kNumLight; i++) {
        light_t *l = &light_props[_currentBufferIndex * kNumLight + i];
        l->color = light_colors[i];
        l->intensity = light_intensities[i];
        simd_float3 rot_dir = simd_cross(vector3(light_dirs[i].x, light_dirs[i].y, light_dirs[i].z), vector3(0.0f, 1.0f, 0.0f));
        simd_float4 dir = matrix_multiply(matrix_from_rotation(_animationTime * 3.0f, rot_dir.x, rot_dir.y, rot_dir.z), light_dirs[i]);
        l->direction = vector3(dir.x, dir.y, dir.z);
    }
    
    // Synchronize buffers
    memcpy(_cameraPropsBuffer.contents + _currentBufferIndex * sizeof(camera_props_t),
           &camera_props[_currentBufferIndex], sizeof(camera_props_t));
    [_cameraPropsBuffer didModifyRange: NSMakeRange(_currentBufferIndex * sizeof(camera_props_t),
                                                    sizeof(camera_props_t))];
    memcpy(_instancePropsBuffer.contents + _currentBufferIndex * sizeof(instance_props_t) * kNumInstance,
           &instance_props[_currentBufferIndex * kNumInstance], sizeof(instance_props_t) * kNumInstance);
    [_instancePropsBuffer didModifyRange: NSMakeRange(_currentBufferIndex * sizeof(instance_props_t) * kNumInstance,
                                                      sizeof(instance_props_t) * kNumInstance)];
    memcpy(_lightPropsBuffer.contents + _currentBufferIndex * sizeof(light_t) * kNumLight,
           &light_props[_currentBufferIndex * kNumLight], sizeof(light_t) * kNumLight);
    [_lightPropsBuffer didModifyRange: NSMakeRange(_currentBufferIndex * sizeof(light_t) * kNumLight,
                                                   sizeof(light_t) * kNumLight)];
    
    _elapsedTime += deltaTime;
    if(_animate)
        _animationTime += deltaTime;
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
    MTLRenderPassDescriptor *lightingRenderPassDescriptor = [[MTLRenderPassDescriptor alloc] init];
    lightingRenderPassDescriptor.colorAttachments[0].texture = self.view.currentDrawable.texture;
    lightingRenderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    lightingRenderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    lightingRenderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0);
    id<MTLRenderCommandEncoder> lightingPassEncoder = [commandBuffer renderCommandEncoderWithDescriptor: lightingRenderPassDescriptor];
    [self renderLighting:lightingPassEncoder];
    
    // present
    [commandBuffer presentDrawable: self.view.currentDrawable];
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer) {
        [self endFrame];
    }];
    [commandBuffer commit];
    
    _currentBufferIndex = (_currentBufferIndex + 1) % kMaxBuffersInFlight;
}

- (void)renderGBuffer:(id<MTLRenderCommandEncoder>)encoder {
    encoder.label = @"G-buffer";
    
    [encoder setRenderPipelineState: _renderPipelineGBuffer];
    [encoder setDepthStencilState: _depthStencil];
    
#if !TEST
    for(MGPMesh *mesh in _meshes) {
        for(MGPSubmesh *submesh in mesh.submeshes) {
            [encoder setVertexBuffer: mesh.metalKitMesh.vertexBuffers[0].buffer
                              offset: 0
                             atIndex: 0];
            [encoder setVertexBuffer: _cameraPropsBuffer
                              offset: _currentBufferIndex * sizeof(camera_props_t)
                             atIndex: 1];
            [encoder setVertexBuffer: _instancePropsBuffer
                              offset: _currentBufferIndex * sizeof(instance_props_t) * kNumInstance
                             atIndex: 2];
            
            [encoder setFragmentTexture: submesh.textures[tex_albedo] atIndex: tex_albedo];
            [encoder setFragmentTexture: submesh.textures[tex_normal] atIndex: tex_normal];
            [encoder setFragmentTexture: submesh.textures[tex_roughness] atIndex: tex_roughness];
            [encoder setFragmentTexture: submesh.textures[tex_metalic] atIndex: tex_metalic];
            [encoder setFragmentBuffer: _cameraPropsBuffer
                                offset: _currentBufferIndex * sizeof(camera_props_t)
                               atIndex: 1];
            [encoder setFragmentBuffer: _instancePropsBuffer
                                offset: _currentBufferIndex * sizeof(instance_props_t) * kNumInstance
                               atIndex: 2];
            
            [encoder drawIndexedPrimitives: submesh.metalKitSubmesh.primitiveType
                                indexCount: submesh.metalKitSubmesh.indexCount
                                 indexType: submesh.metalKitSubmesh.indexType
                               indexBuffer: submesh.metalKitSubmesh.indexBuffer.buffer
                         indexBufferOffset: submesh.metalKitSubmesh.indexBuffer.offset
                             instanceCount: kNumInstance];
        }
    }
#else
    for(MTKSubmesh* submesh in _sphereMesh.submeshes) {
        [encoder setVertexBuffer: _sphereMesh.vertexBuffers[0].buffer
                          offset: 0
                         atIndex: 0];
        [encoder setVertexBuffer: _cameraPropsBuffer
                          offset: _currentBufferIndex * sizeof(camera_props_t)
                         atIndex: 1];
        [encoder setVertexBuffer: _instancePropsBuffer
                          offset: _currentBufferIndex * sizeof(instance_props_t) * kNumInstance
                         atIndex: 2];
        
        [encoder setFragmentBuffer: _cameraPropsBuffer
                            offset: _currentBufferIndex * sizeof(camera_props_t)
                           atIndex: 1];
        [encoder setFragmentBuffer: _instancePropsBuffer
                            offset: _currentBufferIndex * sizeof(instance_props_t) * kNumInstance
                           atIndex: 2];
        
        [encoder drawIndexedPrimitives: submesh.primitiveType
                            indexCount: submesh.indexCount
                             indexType: submesh.indexType
                           indexBuffer: submesh.indexBuffer.buffer
                     indexBufferOffset: submesh.indexBuffer.offset
                         instanceCount: kNumInstance];
    }
#endif
    
    [encoder endEncoding];
}

- (void)renderLighting:(id<MTLRenderCommandEncoder>)encoder {
    encoder.label = @"Lighting";
    [encoder setRenderPipelineState: _renderPipelineLighting];
    [encoder setVertexBuffer: _quadVertexBuffer
                      offset: 0
                     atIndex: 0];
    [encoder setFragmentBuffer: _lightPropsBuffer
                        offset: 0
                       atIndex: 1];
    [encoder setFragmentBuffer: _lightGlobalBuffer
                        offset: 0
                       atIndex: 2];
    [encoder setFragmentTexture: _gBuffer.albedo
                        atIndex: attachment_albedo];
    [encoder setFragmentTexture: _gBuffer.normal
                        atIndex: attachment_normal];
    [encoder setFragmentTexture: _gBuffer.pos
                        atIndex: attachment_pos];
    [encoder setFragmentTexture: _gBuffer.shading
                        atIndex: attachment_shading];
    [encoder drawPrimitives: MTLPrimitiveTypeTriangle
                vertexStart: 0
                vertexCount: 6];
    
    [encoder endEncoding];
}

- (void)resize:(CGSize)newSize {
    [_gBuffer resize:newSize];
}

@end
