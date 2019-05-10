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
#import "../Common/MGPImageBasedLighting.h"
#import "../Common/MetalMath.h"
#import "../Common/MGPCommonVertices.h"

#define STB_IMAGE_IMPLEMENTATION
#import "../Common/STB/stb_image.h"

#ifndef LERP
#define LERP(x,y,t) ((x)*(1.0-(t))+(y)*(t))
#endif

#define TEST 1

const size_t kMaxBuffersInFlight = 3;
const size_t kNumInstance = 8;
const uint32_t kNumLight = 128;
const float kLightIntensityBase = 0.25;
const float kLightIntensityVariation = 3.0;

#define DEG_TO_RAD(x) ((x)*0.0174532925)

@implementation DeferredRenderer {
    camera_props_t camera_props[kMaxBuffersInFlight];
    instance_props_t instance_props[kMaxBuffersInFlight * kNumInstance];
    light_t light_props[kMaxBuffersInFlight * kNumLight];
    light_global_t light_globals[kMaxBuffersInFlight];
    
    size_t _currentBufferIndex;
    float _elapsedTime;
    bool _animate;
    float _animationTime;
    
    BOOL _moveFlags[6];     // Front, Back, Left, Right, Up, Down
    float _moveSpeeds[6];   // same as flags
    NSPoint _mouseDelta, _prevMousePos;
    
    BOOL _mouseDown;
    vector_float3 _cameraPos;
    vector_float3 _cameraRot;
    matrix_float4x4 _cameraRotationMatrix, _cameraRotationInverseMatrix;
    matrix_float4x4 _cameraMatrix, _cameraInverseMatrix;
    
    // props
    id<MTLBuffer> _cameraPropsBuffer;
    id<MTLBuffer> _instancePropsBuffer;
    id<MTLBuffer> _lightPropsBuffer;
    id<MTLBuffer> _lightGlobalBuffer;
    
    // common vertex buffer (quad + cube)
    id<MTLBuffer> _commonVertexBuffer;
    
    // g-buffer
    MGPGBuffer *_gBuffer;
    
    // image-based lighting
    MGPImageBasedLighting *_IBL;
    
    // render pass, pipeline states
    MTLRenderPipelineDescriptor *_baseRenderPipelineDescriptorGBuffer;
    id<MTLRenderPipelineState> _renderPipelineSkybox;
    id<MTLRenderPipelineState> _renderPipelineGBuffer;
    id<MTLRenderPipelineState> _renderPipelineLighting;
    id<MTLRenderPipelineState> _renderPipelinePresent;
    MTLRenderPassDescriptor *_renderPassSkybox;
    MTLRenderPassDescriptor *_renderPassPresent;
    
    // depth-stencil
    id<MTLDepthStencilState> _depthStencil;
    
    // textures
    id<MTLTexture> _equirectangularMapTexture;
    id<MTLTexture> _skyboxDepthTexture;
    
    // Meshes
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
        // space key
        _animate = !_animate;
    }
    if(theEvent.keyCode == 13) {
        // w
        _moveFlags[0] = true;
    }
    if(theEvent.keyCode == 1) {
        // s
        _moveFlags[1] = true;
    }
    if(theEvent.keyCode == 2) {
        // d
        _moveFlags[2] = true;
    }
    if(theEvent.keyCode == 0) {
        // a
        _moveFlags[3] = true;
    }
    if(theEvent.keyCode == 12) {
        // d
        _moveFlags[4] = true;
    }
    if(theEvent.keyCode == 14) {
        // a
        _moveFlags[5] = true;
    }
}

- (void)view:(MGPView *)view keyUp:(NSEvent *)theEvent {
    if(theEvent.keyCode == 13) {
        // w
        _moveFlags[0] = false;
    }
    if(theEvent.keyCode == 1) {
        // s
        _moveFlags[1] = false;
    }
    if(theEvent.keyCode == 2) {
        // d
        _moveFlags[2] = false;
    }
    if(theEvent.keyCode == 0) {
        // a
        _moveFlags[3] = false;
    }
    if(theEvent.keyCode == 12) {
        // d
        _moveFlags[4] = false;
    }
    if(theEvent.keyCode == 14) {
        // a
        _moveFlags[5] = false;
    }
}

- (void)view:(MGPView *)view mouseDown:(NSEvent *)theEvent {
    _mouseDown = YES;
}

- (void)view:(MGPView *)view mouseUp:(NSEvent *)theEvent {
    _mouseDown = NO;
}

- (instancetype)init {
    self = [super init];
    if(self) {
        _animate = YES;
        _cameraPos = vector3(0.0f, 0.0f, -60.0f);
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
    _lightGlobalBuffer = [self.device newBufferWithLength: sizeof(light_globals)
                                                  options: MTLResourceStorageModeManaged];
}

- (void)initAssets {
    // vertex buffer
    _commonVertexBuffer = [self.device newBufferWithLength:1024
                                                   options:MTLResourceStorageModeManaged];
    memcpy(_commonVertexBuffer.contents, QuadVertices, sizeof(QuadVertices));
    memcpy(_commonVertexBuffer.contents + 256, EquirectangularMapVertices, sizeof(EquirectangularMapVertices));
    [_commonVertexBuffer didModifyRange: NSMakeRange(0, 1024)];
    
    // G-buffer
    _gBuffer = [[MGPGBuffer alloc] initWithDevice:self.device
                                          library:self.defaultLibrary
                                             size:CGSizeMake(512,512)];
    
    _baseRenderPipelineDescriptorGBuffer = [[_gBuffer renderPipelineDescriptor] copy];
    
    // IBL
    _IBL = [[MGPImageBasedLighting alloc] initWithDevice: self.device
                                                 library: self.defaultLibrary
                                                   queue: self.queue];
    
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
    
    MTLRenderPipelineDescriptor *renderPipelineDescriptorLighting = [_gBuffer lightingPipelineDescriptor];
    _renderPipelineLighting = [self.device newRenderPipelineStateWithDescriptor: renderPipelineDescriptorLighting
                                                                          error: nil];
    
    MTLRenderPipelineDescriptor *renderPipelineDescriptorPresent = [[MTLRenderPipelineDescriptor alloc] init];
    renderPipelineDescriptorPresent.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm_sRGB;
    renderPipelineDescriptorPresent.colorAttachments[0].blendingEnabled = YES;
    renderPipelineDescriptorPresent.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
    renderPipelineDescriptorPresent.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    renderPipelineDescriptorPresent.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorOne;
    renderPipelineDescriptorPresent.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorOne;
    renderPipelineDescriptorPresent.vertexFunction = [self.defaultLibrary newFunctionWithName: @"screen_vert"];
    renderPipelineDescriptorPresent.fragmentFunction = [self.defaultLibrary newFunctionWithName: @"screen_frag"];
    _renderPipelinePresent = [self.device newRenderPipelineStateWithDescriptor: renderPipelineDescriptorPresent
                                                                         error: nil];
    
    MTLRenderPipelineDescriptor *renderPipelineDescriptorSkybox = [[MTLRenderPipelineDescriptor alloc] init];
    renderPipelineDescriptorSkybox.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm_sRGB;
    renderPipelineDescriptorSkybox.vertexFunction = [self.defaultLibrary newFunctionWithName: @"skybox_vert"];
    renderPipelineDescriptorSkybox.fragmentFunction = [self.defaultLibrary newFunctionWithName: @"skybox_frag"];
    renderPipelineDescriptorSkybox.depthAttachmentPixelFormat = _gBuffer.depth.pixelFormat;
    _renderPipelineSkybox = [self.device newRenderPipelineStateWithDescriptor: renderPipelineDescriptorSkybox
                                                                        error: nil];
    
    // render pass
    _renderPassSkybox = [[MTLRenderPassDescriptor alloc] init];
    _renderPassSkybox.colorAttachments[0].loadAction = MTLLoadActionClear;
    _renderPassSkybox.colorAttachments[0].storeAction = MTLStoreActionStore;
    _renderPassSkybox.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0);
    _renderPassSkybox.depthAttachment.loadAction = MTLLoadActionClear;
    _renderPassSkybox.depthAttachment.storeAction = MTLStoreActionStore;
    
    _renderPassPresent = [[MTLRenderPassDescriptor alloc] init];
    _renderPassPresent.colorAttachments[0].loadAction = MTLLoadActionDontCare;
    _renderPassPresent.colorAttachments[0].storeAction = MTLStoreActionStore;
    
    // depth-stencil
    MTLDepthStencilDescriptor *depthStencilDescriptor = [[MTLDepthStencilDescriptor alloc] init];
    depthStencilDescriptor.depthWriteEnabled = YES;
    depthStencilDescriptor.depthCompareFunction = MTLCompareFunctionLess;
    _depthStencil = [self.device newDepthStencilStateWithDescriptor: depthStencilDescriptor];
    
    // textures
    NSString *skyboxImagePath = [[NSBundle mainBundle] pathForResource:@"Tropical_Beach_3k"
                                                                ofType:@"hdr"];
    int skyboxWidth, skyboxHeight, skyboxComps;
    float* skyboxImageData = stbi_loadf(skyboxImagePath.UTF8String, &skyboxWidth, &skyboxHeight, &skyboxComps, 4);
    
    
    MTLTextureDescriptor *skyboxTextureDescriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA32Float
                                                                                                       width:skyboxWidth
                                                                                                      height:skyboxHeight
                                                                                                   mipmapped:NO];
    skyboxTextureDescriptor.usage = MTLTextureUsageShaderRead;
    _equirectangularMapTexture = [self.device newTextureWithDescriptor: skyboxTextureDescriptor];
    [_equirectangularMapTexture replaceRegion:MTLRegionMake2D(0, 0, skyboxWidth, skyboxHeight)
                                  mipmapLevel:0
                                    withBytes:skyboxImageData
                                  bytesPerRow:16*skyboxWidth];
    _IBL.environmentEquirectangularMap = _equirectangularMapTexture;
    stbi_image_free(skyboxImageData);
}

- (void)_initSkyboxDepthTexture {
    MTLTextureDescriptor *desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatDepth32Float_Stencil8
                                                                                    width:_gBuffer.size.width
                                                                                   height:_gBuffer.size.height
                                                                                mipmapped:NO];
    desc.usage = MTLTextureUsageRenderTarget;
    desc.storageMode = MTLStorageModePrivate;
    _skyboxDepthTexture = [self.device newTextureWithDescriptor:desc];
}

- (void)update:(float)deltaTime {
    // mouse pos
    NSPoint mousePos = [NSEvent mouseLocation];
    if(_prevMousePos.x == 0.0f && _prevMousePos.y == 0.0f)
        _prevMousePos = mousePos;
    _mouseDelta = NSMakePoint(mousePos.x - _prevMousePos.x, mousePos.y - _prevMousePos.y);
    _prevMousePos = mousePos;
    
    // camera
    [self _updateCameraMatrix: deltaTime];
    [self _updateUniformBuffers: deltaTime];
}

- (void)_updateCameraMatrix: (float)deltaTime {
    // camera rotation
    if(_mouseDown) {
        NSPoint pixelMouseDelta = [self.view convertPointToBacking: _mouseDelta];
        _cameraRot.y = _cameraRot.y + pixelMouseDelta.x / (0.5f * _gBuffer.size.height) * M_PI_2;
        _cameraRot.x = MIN(MAX(_cameraRot.x + pixelMouseDelta.y / (0.5f * _gBuffer.size.height) * M_PI_2, -M_PI*0.4), M_PI*0.4);
    }
    _cameraRotationMatrix = matrix_multiply(matrix_from_rotation(_cameraRot.y, 0, 1, 0),
                                            matrix_from_rotation(-_cameraRot.x, 1, 0, 0));
    _cameraRotationInverseMatrix = matrix_invert(_cameraRotationMatrix);
    
    // move
    static int columnIndices[] = {
        2,2,0,0,1,1
    };
    for(int i = 0; i < 6; i++) {
        float sign = (i % 2) ? -1.0f : 1.0f;
        _moveSpeeds[i] = LERP(_moveSpeeds[i], _moveFlags[i] ? 100.0f : 0.0f, deltaTime * 14);
        _cameraPos = _cameraPos + _cameraRotationMatrix.columns[columnIndices[i]].xyz * deltaTime * _moveSpeeds[i] * sign;
    }
    matrix_float4x4 cameraTranslationMatrix = matrix_from_translation(_cameraPos.x, _cameraPos.y, _cameraPos.z);
    _cameraMatrix = matrix_multiply(cameraTranslationMatrix, _cameraRotationMatrix);
    _cameraInverseMatrix = matrix_invert(_cameraMatrix);
}

- (void)_updateUniformBuffers: (float)deltaTime {
    // Update camera properties
    camera_props[_currentBufferIndex].view = _cameraInverseMatrix;
    camera_props[_currentBufferIndex].projection = matrix_from_perspective_fov_aspectLH(DEG_TO_RAD(60.0f), _gBuffer.size.width / _gBuffer.size.height, 0.5f, 300.0f);
    camera_props[_currentBufferIndex].viewInverse = _cameraMatrix;
    camera_props[_currentBufferIndex].rotation = _cameraRotationInverseMatrix;
    
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
            light_intensities[i] = kLightIntensityBase + rand() / (float)RAND_MAX * kLightIntensityVariation;
            light_dirs[i] = simd_normalize(vector4(rand() / (float)RAND_MAX - 0.5f, rand() / (float)RAND_MAX - 0.5f,
                                                   rand() / (float)RAND_MAX - 0.5f, 0.0f));
        }
    }
    
    for(NSInteger i = 0; i < _numLights; i++) {
        light_t *l = &light_props[_currentBufferIndex * kNumLight + i];
        l->color = light_colors[i];
        l->intensity = light_intensities[i];
        simd_float3 rot_dir = simd_cross(vector3(light_dirs[i].x, light_dirs[i].y, light_dirs[i].z), vector3(0.0f, 1.0f, 0.0f));
        simd_float4 dir = matrix_multiply(matrix_from_rotation(_animationTime * 3.0f, rot_dir.x, rot_dir.y, rot_dir.z), light_dirs[i]);
        dir = matrix_multiply(dir, _cameraRotationMatrix);
        l->direction = vector3(dir.x, dir.y, dir.z);
    }
    
    light_globals[_currentBufferIndex].num_light = _numLights;
    
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
    
    memcpy(_lightGlobalBuffer.contents + _currentBufferIndex * sizeof(light_global_t), &light_globals[_currentBufferIndex], sizeof(light_global_t));
    [_lightGlobalBuffer didModifyRange: NSMakeRange(_currentBufferIndex * sizeof(light_global_t),
                                                    sizeof(light_global_t))];
    
    _elapsedTime += deltaTime;
    if(_animate)
        _animationTime += deltaTime;
}

- (void)render {
    [self beginFrame];
    
    // begin
    id<MTLCommandBuffer> commandBuffer = [self.queue commandBuffer];
    commandBuffer.label = @"Render";
    
    // skybox pass
    _renderPassSkybox.colorAttachments[0].texture = self.view.currentDrawable.texture;
    _renderPassSkybox.depthAttachment.texture = _skyboxDepthTexture;
    id<MTLRenderCommandEncoder> skyboxPassEncoder = [commandBuffer renderCommandEncoderWithDescriptor: _renderPassSkybox];
    [self renderSkybox:skyboxPassEncoder];
    
    // Irradiance
    static bool a = false;
    if(!a) {
        a = true;
        [_IBL renderIrradianceMap: commandBuffer];
    }
    
    // G-buffer pass
    id<MTLRenderCommandEncoder> gBufferPassEncoder = [commandBuffer renderCommandEncoderWithDescriptor: _gBuffer.renderPassDescriptor];
    [self renderGBuffer:gBufferPassEncoder];
    
    // lighting pass
    id<MTLRenderCommandEncoder> lightingPassEncoder = [commandBuffer renderCommandEncoderWithDescriptor: _gBuffer.lightingPassDescriptor];
    [self renderLighting:lightingPassEncoder];
    
    // present to framebuffer
    _renderPassPresent.colorAttachments[0].texture = self.view.currentDrawable.texture;
    id<MTLRenderCommandEncoder> presentCommandEncoder = [commandBuffer renderCommandEncoderWithDescriptor: _renderPassPresent];
    [self renderFramebuffer:presentCommandEncoder];
    
    // present
    [commandBuffer presentDrawable: self.view.currentDrawable];
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer) {
        [self endFrame];
    }];
    [commandBuffer commit];
    
    _currentBufferIndex = (_currentBufferIndex + 1) % kMaxBuffersInFlight;
}

- (void)renderSkybox:(id<MTLRenderCommandEncoder>)encoder {
    encoder.label = @"Skybox";
    [encoder setRenderPipelineState: _renderPipelineSkybox];
    [encoder setDepthStencilState: _depthStencil];
    [encoder setCullMode: MTLCullModeBack];
    
    [encoder setVertexBuffer: _commonVertexBuffer
                      offset: 256
                     atIndex: 0];
    [encoder setVertexBuffer: _cameraPropsBuffer
                      offset: _currentBufferIndex * sizeof(camera_props_t)
                     atIndex: 1];
    [encoder setFragmentTexture: _equirectangularMapTexture
                        atIndex: 0];
    [encoder drawPrimitives: MTLPrimitiveTypeTriangle
                vertexStart: 0
                vertexCount: 36];
    [encoder endEncoding];
}

- (void)renderGBuffer:(id<MTLRenderCommandEncoder>)encoder {
    encoder.label = @"G-buffer";
    [encoder setRenderPipelineState: _renderPipelineGBuffer];
    [encoder setDepthStencilState: _depthStencil];
    [encoder setCullMode: MTLCullModeBack];
    
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
    [encoder setCullMode: MTLCullModeBack];
    [encoder setVertexBuffer: _commonVertexBuffer
                      offset: 0
                     atIndex: 0];
    [encoder setFragmentBuffer: _cameraPropsBuffer
                        offset: _currentBufferIndex * sizeof(camera_props_t)
                       atIndex: 1];
    [encoder setFragmentBuffer: _lightPropsBuffer
                        offset: _currentBufferIndex * sizeof(light_t) * kNumLight
                       atIndex: 2];
    [encoder setFragmentBuffer: _lightGlobalBuffer
                        offset: _currentBufferIndex * sizeof(light_global_t)
                       atIndex: 3];
    [encoder setFragmentTexture: _gBuffer.albedo
                        atIndex: attachment_albedo];
    [encoder setFragmentTexture: _gBuffer.normal
                        atIndex: attachment_normal];
    [encoder setFragmentTexture: _gBuffer.pos
                        atIndex: attachment_pos];
    [encoder setFragmentTexture: _gBuffer.shading
                        atIndex: attachment_shading];
    [encoder setFragmentTexture: _IBL.irradianceEquirectangularMap
                        atIndex: attachment_irradiance];
    [encoder drawPrimitives: MTLPrimitiveTypeTriangle
                vertexStart: 0
                vertexCount: 6];
    
    [encoder endEncoding];
}

- (void)renderFramebuffer:(id<MTLRenderCommandEncoder>)encoder {
    encoder.label = @"Present";
    [encoder setRenderPipelineState: _renderPipelinePresent];
    [encoder setCullMode: MTLCullModeBack];
    [encoder setVertexBuffer: _commonVertexBuffer
                      offset: 0
                     atIndex: 0];
    [encoder setFragmentTexture: _gBuffer.lighting
                        atIndex: 0];
    [encoder drawPrimitives: MTLPrimitiveTypeTriangle
                vertexStart: 0
                vertexCount: 6];
    
    [encoder endEncoding];
}

- (void)resize:(CGSize)newSize {
    [_gBuffer resize:newSize];
    [self _initSkyboxDepthTexture];
}

@end
