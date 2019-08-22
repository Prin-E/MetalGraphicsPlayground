//
//  DeferredRenderer.m
//  MetalPostProcessing
//
//  Created by 이현우 on 03/05/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import "DeferredRenderer.h"
#import "../Common/Shaders/SharedStructures.h"
#import "../Common/Sources/Rendering/MGPGBuffer.h"
#import "../Common/Sources/Model/MGPMesh.h"
#import "../Common/Sources/Model/MGPImageBasedLighting.h"
#import "../Common/Sources/Utility/MetalMath.h"
#import "../Common/Sources/Utility/MGPCommonVertices.h"
#import "../Common/Sources/Utility/MGPTextureLoader.h"
#import "../Common/Sources/Rendering/MGPPostProcessing.h"
#import "../Common/Sources/Rendering/MGPPostProcessingLayer.h"
#import "../Common/Sources/Model/MGPShadowBuffer.h"
#import "../Common/Sources/Model/MGPShadowManager.h"
#import "../Common/Sources/Model/MGPLight.h"
#import "../Common/Sources/Model/MGPCamera.h"
#import "../Common/Sources/Model/MGPBoundingVolume.h"
#import "../Common/Sources/Rendering/MGPGizmos.h"

#define STB_IMAGE_IMPLEMENTATION
#import "../Common/STB/stb_image.h"

#ifndef LERP
#define LERP(x,y,t) ((x)*(1.0-(t))+(y)*(t))
#endif

#define TEST 1

const size_t kMaxBuffersInFlight = 3;
const size_t kNumInstance = 1;
const uint32_t kNumLight = 128;
const float kLightIntensityBase = 1.0f;
const float kLightIntensityVariation = 1.0f;

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
    BOOL _moveFast;
    float _moveSpeeds[6];   // same as flags
    NSPoint _mouseDelta, _prevMousePos;
    
    BOOL _mouseDown;
    MGPCamera *_camera;
    BOOL _isOrthographic;
    BOOL _drawGizmos;
    BOOL _cull;
    
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
    NSMutableArray<MGPImageBasedLighting *> *_IBLs;
    NSInteger _currentIBLIndex, _renderingIBLIndex;
    
    // render pass, pipeline states
    id<MTLRenderPipelineState> _renderPipelineSkybox;
    id<MTLRenderPipelineState> _renderPipelinePrepass;
    id<MTLRenderPipelineState> _renderPipelineLighting;
    id<MTLRenderPipelineState> _renderPipelineShading;
    id<MTLRenderPipelineState> _renderPipelinePresent;
    MTLRenderPassDescriptor *_renderPassSkybox;
    MTLRenderPassDescriptor *_renderPassPresent;
    
    // depth-stencil
    id<MTLDepthStencilState> _depthStencil;
    
    // textures
    id<MTLTexture> _skyboxDepthTexture;
    
    // Meshes
    NSArray<MGPMesh *> *_meshes;
    
    // Lights
    NSMutableArray<MGPLight *> *_lights;
    
    // Post-processing
    MGPPostProcessing *_postProcess;
    
    // Shadow
    MGPShadowManager *_shadowManager;
    
    // Gizmos
    MGPGizmos *_gizmos;
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
    if(theEvent.keyCode == 48) {
        // tab
        MGPProjectionState proj = _camera.projectionState;
        _isOrthographic = !_isOrthographic;
        _camera.projectionState = proj;
    }
    if(theEvent.keyCode == 18) {
        // 1
        _drawGizmos = !_drawGizmos;
    }
    if(theEvent.keyCode == 19) {
        // 2
        _cull = !_cull;
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

- (void)view:(MGPView *)view flagsChanged:(NSEvent *)theEvent {
    // shift
    _moveFast = (theEvent.modifierFlags & NSEventModifierFlagShift) != 0;
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
        _animate = NO;
        _numLights = 2;
        _roughness = 1.0f;
        _metalic = 0.0f;
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
    // vertex buffer (mesh)
    _commonVertexBuffer = [self.device newBufferWithLength:1024
                                                   options:MTLResourceStorageModeManaged];
    memcpy(_commonVertexBuffer.contents, QuadVertices, sizeof(QuadVertices));
    memcpy(_commonVertexBuffer.contents + 256, SkyboxVertices, sizeof(SkyboxVertices));
    [_commonVertexBuffer didModifyRange: NSMakeRange(0, 1024)];
    
    // G-buffer
    _gBuffer = [[MGPGBuffer alloc] initWithDevice:self.device
                                          library:self.defaultLibrary
                                             size:CGSizeMake(512,512)];
    
    // IBL
    _IBLs = [NSMutableArray array];
    
    /*
    NSArray<NSString*> *skyboxNames = @[@"Tropical_Beach_3k"];
    for(NSInteger i = 0; i < skyboxNames.count; i++) {
        NSString *skyboxImagePath = [[NSBundle mainBundle] pathForResource:skyboxNames[i]
                                                                    ofType:@"hdr"];
        int skyboxWidth, skyboxHeight, skyboxComps;
        float* skyboxImageData = stbi_loadf(skyboxImagePath.UTF8String, &skyboxWidth, &skyboxHeight, &skyboxComps, 4);
        
        MTLTextureDescriptor *skyboxTextureDescriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA32Float
                                                                                                           width:skyboxWidth
                                                                                                          height:skyboxHeight
                                                                                                       mipmapped:NO];
        skyboxTextureDescriptor.usage = MTLTextureUsageShaderRead;
        id<MTLTexture> skyboxTexture = [self.device newTextureWithDescriptor: skyboxTextureDescriptor];
        [skyboxTexture replaceRegion:MTLRegionMake2D(0, 0, skyboxWidth, skyboxHeight)
                         mipmapLevel:0
                           withBytes:skyboxImageData
                         bytesPerRow:16*skyboxWidth];
        stbi_image_free(skyboxImageData);
        
        MGPImageBasedLighting *IBL = [[MGPImageBasedLighting alloc] initWithDevice: self.device
                                                                           library: self.defaultLibrary
                                                                equirectangularMap: skyboxTexture];
        [_IBLs addObject: IBL];
    }
    */
    
    // vertex descriptor
    MDLVertexDescriptor *mdlVertexDescriptor = MTKModelIOVertexDescriptorFromMetal(_gBuffer.baseVertexDescriptor);
    mdlVertexDescriptor.attributes[attrib_pos].name = MDLVertexAttributePosition;
    mdlVertexDescriptor.attributes[attrib_uv].name = MDLVertexAttributeTextureCoordinate;
    mdlVertexDescriptor.attributes[attrib_normal].name = MDLVertexAttributeNormal;
    mdlVertexDescriptor.attributes[attrib_tangent].name = MDLVertexAttributeTangent;
    mdlVertexDescriptor.attributes[attrib_bitangent].name = MDLVertexAttributeBitangent;
    
    // meshes
    _meshes = [MGPMesh loadMeshesFromURL: [[NSBundle mainBundle] URLForResource: @"sponza"
                                                                  withExtension: @"obj"]
                 modelIOVertexDescriptor: mdlVertexDescriptor
                                  device: self.device
                                   error: nil];
    
    // build render pipeline
    MGPGBufferPrepassFunctionConstants prepassConstants = {};
    prepassConstants.hasAlbedoMap = _meshes[0].submeshes[0].textures[tex_albedo] != NSNull.null;
    prepassConstants.hasNormalMap = _meshes[0].submeshes[0].textures[tex_normal] != NSNull.null;
    prepassConstants.hasRoughnessMap = _meshes[0].submeshes[0].textures[tex_roughness] != NSNull.null;
    prepassConstants.hasMetalicMap = _meshes[0].submeshes[0].textures[tex_metalic] != NSNull.null;
    prepassConstants.hasOcclusionMap = _meshes[0].submeshes[0].textures[tex_occlusion] != NSNull.null;
    prepassConstants.hasAnisotropicMap = _meshes[0].submeshes[0].textures[tex_anisotropic] != NSNull.null;
    prepassConstants.flipVertically = YES;  // for sponza textures
    MGPGBufferShadingFunctionConstants shadingConstants = {};
    shadingConstants.hasIBLIrradianceMap = _IBLs.count > 0;
    shadingConstants.hasIBLSpecularMap = _IBLs.count > 0;
    shadingConstants.hasSSAOMap = YES;
    _renderPipelinePrepass = [_gBuffer renderPipelineStateWithConstants: prepassConstants
                                                                  error: nil];
    _renderPipelineLighting = [_gBuffer lightingPipelineStateWithError: nil];
    _renderPipelineShading = [_gBuffer shadingPipelineStateWithConstants: shadingConstants
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
    
    // lights
    _lights = [[NSMutableArray alloc] initWithCapacity: kNumLight];
    for(int i = 0; i < kNumLight; i++) {
        [_lights addObject: [[MGPLight alloc] init]];
    }
    
    // camera
    _camera = [[MGPCamera alloc] init];
    _camera.position = simd_make_float3(0, 50, -60);
    
    // projection
    MGPProjectionState projection = _camera.projectionState;
    projection.aspectRatio = _gBuffer.size.width / _gBuffer.size.height;
    projection.fieldOfView = DEG_TO_RAD(60.0);
    projection.nearPlane = 1.0f;
    projection.farPlane = 5000.0f;
    projection.orthographicSize = 500;
    _camera.projectionState = projection;
    
    // shadow
    _shadowManager = [[MGPShadowManager alloc] initWithDevice: self.device
                                                      library: self.defaultLibrary
                                             vertexDescriptor: _gBuffer.baseVertexDescriptor];
    
    // post-process
    _postProcess = [[MGPPostProcessing alloc] initWithDevice: self.device
                                                     library: self.defaultLibrary];
    _postProcess.gBuffer = _gBuffer;
    _postProcess.cameraBuffer = _cameraPropsBuffer;
    MGPPostProcessingLayerSSAO *ssao = [[MGPPostProcessingLayerSSAO alloc] initWithDevice: self.device
                                                                                 library: self.defaultLibrary];
    ssao.intensity = 0.8f;
    ssao.radius = 50.0f;
    ssao.bias = 2.0f;
    ssao.numSamples = 48;
    [_postProcess addLayer: ssao];
    [_postProcess resize: _gBuffer.size];
    
    _gizmos = [[MGPGizmos alloc] initWithDevice:self.device
                                        library:self.defaultLibrary
                                  gizmoCapacity:8
                              maxBuffersInFight:kMaxBuffersInFlight];
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
    [self _updateCamera: deltaTime];
    [self _updateUniformBuffers: deltaTime];
    _postProcess.currentBufferIndex = _currentBufferIndex;
}

- (void)_updateCamera: (float)deltaTime {
    // rotation
    if(_mouseDown) {
        NSPoint pixelMouseDelta = [self.view convertPointToBacking: _mouseDelta];
        simd_float3 rot = _camera.rotation;
        rot.y = rot.y + pixelMouseDelta.x / (0.5f * _gBuffer.size.height) * M_PI_2;
        rot.x = MIN(MAX(rot.x - pixelMouseDelta.y / (0.5f * _gBuffer.size.height) * M_PI_2, -M_PI*0.4), M_PI*0.4);
        _camera.rotation = rot;
    }
    
    // move
    static int columnIndices[] = { 2, 2, 0, 0, 1, 1 };
    simd_float4x4 rotationMatrix = _camera.cameraToWorldRotationMatrix;
    simd_float3 positionAdd = {};
    BOOL positionIsChanged = NO;
    for(int i = 0; i < 6; i++) {
        float sign = (i % 2) ? -1.0f : 1.0f;
        _moveSpeeds[i] = LERP(_moveSpeeds[i], _moveFlags[i] ? 100.0f * (_moveFast ? 5.0f : 1.0f) : 0.0f, deltaTime * 14);
        if(_moveSpeeds[i] > 0.0001f) {
            simd_float3 direction = rotationMatrix.columns[columnIndices[i]].xyz;
            positionAdd += direction * deltaTime * _moveSpeeds[i] * sign;
            positionIsChanged = YES;
        }
    }
    if(positionIsChanged)
        _camera.position += positionAdd;
    
    // update animated orthographic rate
    MGPProjectionState proj = _camera.projectionState;
    BOOL orthoRateIsChanged = NO;
    if(_isOrthographic && proj.orthographicRate < 1.0f) {
        proj.orthographicRate = simd_min(proj.orthographicRate + deltaTime * 2.0f, 1.0f);
        orthoRateIsChanged = YES;
    }
    else if(!_isOrthographic && proj.orthographicRate > 0.0f) {
        proj.orthographicRate = simd_max(proj.orthographicRate - deltaTime * 2.0f, 0.0f);
        orthoRateIsChanged = YES;
    }
    if(orthoRateIsChanged)
        _camera.projectionState = proj;
}

- (void)_updateUniformBuffers: (float)deltaTime {
    // Update camera properties
    camera_props[_currentBufferIndex] = _camera.shaderProperties;
    
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
    static simd_float3 instance_albedo[kNumInstance];
    static BOOL init_instance_albedo = NO;
    if(!init_instance_albedo) {
        init_instance_albedo = YES;
        for(int i = 0; i < kNumInstance; i++) {
            instance_albedo[i] = vector3(0.5f + rand() / (float)RAND_MAX * 0.5f,
                                         0.5f + rand() / (float)RAND_MAX * 0.5f,
                                         0.5f + rand() / (float)RAND_MAX * 0.5f);
        }
    }
    
    for(NSInteger i = 0; i < kNumInstance; i++) {
        instance_props_t *p = &instance_props[_currentBufferIndex * kNumInstance + i];
        p->model = matrix_from_translation(instance_pos[i].x, instance_pos[i].y, instance_pos[i].z);
        p->material.albedo = instance_albedo[i];
        p->material.roughness = self.roughness;
        p->material.metalic = self.metalic;
        p->material.anisotropy = self.anisotropy;
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
            light_dirs[i] = simd_normalize(vector4(rand() / (float)RAND_MAX - 0.5f,
                                                   -rand() / (float)RAND_MAX - 0.25f,
                                                   rand() / (float)RAND_MAX - 0.5f, 0.0f));
        }
    }
    
    for(NSInteger i = 0; i < _numLights; i++) {
        simd_float3 rot_dir = vector3(0.0f, 1.0f, 0.0f);
        simd_float4 dir = matrix_multiply(matrix_from_rotation(_animationTime * 3.0f, rot_dir.x, rot_dir.y, rot_dir.z), light_dirs[i]);
        
        // set light properties
        MGPLight *light = _lights[i];
        light.color = light_colors[i];
        light.intensity = light_intensities[i];
        light.direction = simd_make_float3(dir);
        light.position = -light.direction * 3000.0f;
        light.castShadows = YES;
        light.shadowBias = 0.00001f;
        
        // light properties -> buffer
        light_t *light_props_ptr = &light_props[_currentBufferIndex * kNumLight + i];
        *light_props_ptr = light.shaderProperties;
    }
    light_globals[_currentBufferIndex].num_light = _numLights;
    light_globals[_currentBufferIndex].ambient_color = vector3(0.1f, 0.1f, 0.1f);
    light_globals[_currentBufferIndex].light_projection = matrix_from_perspective_fov_aspectLH(DEG_TO_RAD(60.0f), _gBuffer.size.width / _gBuffer.size.height, 1.0f, 5000.0f);
    
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
           &light_props[_currentBufferIndex * kNumLight], sizeof(light_t) * _numLights);
    [_lightPropsBuffer didModifyRange: NSMakeRange(_currentBufferIndex * sizeof(light_t) * kNumLight,
                                                   sizeof(light_t) * _numLights)];
    
    memcpy(_lightGlobalBuffer.contents + _currentBufferIndex * sizeof(light_global_t), &light_globals[_currentBufferIndex], sizeof(light_global_t));
    [_lightGlobalBuffer didModifyRange: NSMakeRange(_currentBufferIndex * sizeof(light_global_t),
                                                    sizeof(light_global_t))];
    
    _elapsedTime += deltaTime;
    if(_animate)
        _animationTime += deltaTime;
}

- (void)render {
    [self beginFrame];
    
    if(_IBLs.count > 0) {
        if(_IBLs[_currentIBLIndex].isAnyRenderingRequired) {
            [self performPrefilterPass];
        }
        else {
            _renderingIBLIndex = _currentIBLIndex;
        }
    }
    
    [self performRenderingPassWithCompletionHandler:^{
        [self endFrame];
    }];
    
    _currentBufferIndex = (_currentBufferIndex + 1) % kMaxBuffersInFlight;
}

- (void)performPrefilterPass {
    id<MTLCommandBuffer> commandBuffer = [self.queue commandBuffer];
    commandBuffer.label = @"Prefilter";
    
    [_IBLs[_currentIBLIndex] render: commandBuffer];
    
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer) {
        self->_renderingIBLIndex = self->_currentIBLIndex;
    }];
    [commandBuffer commit];
}

- (void)performRenderingPassWithCompletionHandler: (void(^)(void))handler {
    // begin
    id<MTLCommandBuffer> commandBuffer = [self.queue commandBuffer];
    commandBuffer.label = @"Render";
    
    // prepare gizmo encoding
    [_gizmos prepareEncodingWithColorTexture:_gBuffer.output
                                depthTexture:_gBuffer.depth
                                cameraBuffer:_cameraPropsBuffer
                                 bufferIndex:_currentBufferIndex];
    
    // skybox pass
    _renderPassSkybox.colorAttachments[0].texture = self.view.currentDrawable.texture;
    _renderPassSkybox.depthAttachment.texture = _skyboxDepthTexture;
    id<MTLRenderCommandEncoder> skyboxPassEncoder = [commandBuffer renderCommandEncoderWithDescriptor: _renderPassSkybox];
    [self renderSkybox:skyboxPassEncoder];
    
    // Post-process before prepass
    [_postProcess render: commandBuffer
       forRenderingOrder: MGPPostProcessingRenderingOrderBeforePrepass];
    
    // G-buffer prepass
    id<MTLRenderCommandEncoder> prepassEncoder = [commandBuffer renderCommandEncoderWithDescriptor: _gBuffer.renderPassDescriptor];
    [self renderGBuffer:prepassEncoder];
     
    // Shadowmap Passes
    [self renderShadows: commandBuffer];
    
    // Post-process before light pass
    [_postProcess render: commandBuffer
       forRenderingOrder: MGPPostProcessingRenderingOrderBeforeLightPass];
    
    // G-buffer light-accumulation pass
    id<MTLRenderCommandEncoder> lightingPassEncoder = [commandBuffer renderCommandEncoderWithDescriptor: _gBuffer.lightingPassDescriptor];
    [self renderLighting:lightingPassEncoder];
    
    // Post-process before shade pass
    [_postProcess render: commandBuffer
       forRenderingOrder: MGPPostProcessingRenderingOrderBeforeShadePass];
    
    // G-buffer shade pass
    id<MTLRenderCommandEncoder> shadingPassEncoder = [commandBuffer renderCommandEncoderWithDescriptor: _gBuffer.shadingPassDescriptor];
    [self renderShading:shadingPassEncoder];
    
    // Post-process before prepass
    [_postProcess render: commandBuffer
       forRenderingOrder: MGPPostProcessingRenderingOrderAfterShadePass];
    
    // Encode gizmos
    [_gizmos encodeToCommandBuffer: commandBuffer];
    
    // present to framebuffer
    _renderPassPresent.colorAttachments[0].texture = self.view.currentDrawable.texture;
    id<MTLRenderCommandEncoder> presentCommandEncoder = [commandBuffer renderCommandEncoderWithDescriptor: _renderPassPresent];
    [self renderFramebuffer:presentCommandEncoder];
    
    // present
    [commandBuffer presentDrawable: self.view.currentDrawable];
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer) {
        if(handler != nil)
            handler();
    }];
    [commandBuffer commit];
}

- (void)renderSkybox:(id<MTLRenderCommandEncoder>)encoder {
    encoder.label = @"Skybox";
    [encoder setRenderPipelineState: _renderPipelineSkybox];
    [encoder setDepthStencilState: _depthStencil];
    [encoder setCullMode: MTLCullModeBack];
    
    if(_IBLs.count > 0) {
        [encoder setVertexBuffer: _commonVertexBuffer
                          offset: 256
                         atIndex: 0];
        [encoder setVertexBuffer: _cameraPropsBuffer
                          offset: _currentBufferIndex * sizeof(camera_props_t)
                         atIndex: 1];
        [encoder setFragmentTexture: _IBLs[_renderingIBLIndex].environmentMap
                            atIndex: 0];
        [encoder drawPrimitives: MTLPrimitiveTypeTriangle
                    vertexStart: 0
                    vertexCount: 36];
    }
    [encoder endEncoding];
}

- (void)renderObjects:(id<MTLRenderCommandEncoder>)encoder
         bindTextures:(BOOL)bindTextures {
    MGPFrustum *frustum = _camera.frustum;
    
    for(MGPMesh *mesh in _meshes) {
        for(MGPSubmesh *submesh in mesh.submeshes) {
            id<MGPBoundingVolume> volume = submesh.volume;
            if(_cull) {
                if([volume isCulledInFrustum:frustum])
                    continue;
            }
            if(bindTextures && _drawGizmos) {
                if([volume class] == [MGPBoundingSphere class]) {
                    MGPBoundingSphere *sphere = volume;
                    [_gizmos drawWireframeSphereWithCenter:sphere.position
                                                    radius:sphere.radius];
                }
            }
            
            [encoder setVertexBuffer: mesh.metalKitMesh.vertexBuffers[0].buffer
                              offset: 0
                             atIndex: 0];
            
            if(bindTextures) {
                for(int i = 0; i < tex_total; i++) {
                    if(submesh.textures[i] != NSNull.null) {
                        [encoder setFragmentTexture: submesh.textures[i] atIndex: i];
                    }
                    else {
                        [encoder setFragmentTexture: nil atIndex: i];
                    }
                }
            }
            
            [encoder drawIndexedPrimitives: submesh.metalKitSubmesh.primitiveType
                                indexCount: submesh.metalKitSubmesh.indexCount
                                 indexType: submesh.metalKitSubmesh.indexType
                               indexBuffer: submesh.metalKitSubmesh.indexBuffer.buffer
                         indexBufferOffset: submesh.metalKitSubmesh.indexBuffer.offset
                             instanceCount: kNumInstance];
        }
    }
}

- (void)renderGBuffer:(id<MTLRenderCommandEncoder>)encoder {
    encoder.label = @"G-buffer";
    [encoder setRenderPipelineState: _renderPipelinePrepass];
    [encoder setDepthStencilState: _depthStencil];
    [encoder setCullMode: MTLCullModeBack];
    
    // camera
    [encoder setVertexBuffer: _cameraPropsBuffer
                      offset: _currentBufferIndex * sizeof(camera_props_t)
                     atIndex: 1];
    [encoder setFragmentBuffer: _cameraPropsBuffer
                        offset: _currentBufferIndex * sizeof(camera_props_t)
                       atIndex: 1];
    
    // instance
    [encoder setVertexBuffer: _instancePropsBuffer
                      offset: _currentBufferIndex * sizeof(instance_props_t) * kNumInstance
                     atIndex: 2];
    [encoder setFragmentBuffer: _instancePropsBuffer
                        offset: _currentBufferIndex * sizeof(instance_props_t) * kNumInstance
                       atIndex: 2];
    
    [self renderObjects: encoder
           bindTextures: YES];
    [encoder endEncoding];
}

- (void)renderShadows:(id<MTLCommandBuffer>)buffer {
    for(int i = 0; i < _numLights; i++) {
        MGPShadowBuffer *shadowBuffer = [_shadowManager newShadowBufferForLight: _lights[i]
                                                                     resolution: 1024
                                                                  cascadeLevels: 1];
        
        if(shadowBuffer != nil) {
            id<MTLRenderCommandEncoder> encoder = [buffer renderCommandEncoderWithDescriptor: shadowBuffer.shadowPass];
            encoder.label = [NSString stringWithFormat: @"Shadow #%d", i+1];
            [encoder setRenderPipelineState: _shadowManager.shadowPipeline];
            [encoder setDepthStencilState: _depthStencil];
            [encoder setCullMode: MTLCullModeBack];
            
            [encoder setVertexBuffer: _lightPropsBuffer
                              offset: (_currentBufferIndex * kNumLight + i) * sizeof(light_t)
                             atIndex: 1];
            [encoder setVertexBuffer: _lightGlobalBuffer
                              offset: _currentBufferIndex * sizeof(light_global_t)
                             atIndex: 2];
            [encoder setVertexBuffer: _instancePropsBuffer
                              offset: _currentBufferIndex * sizeof(instance_props_t) * kNumInstance
                             atIndex: 3];
            
            [self renderObjects: encoder
                   bindTextures: NO];
            [encoder endEncoding];
        }
    }
}

- (void)renderLighting:(id<MTLRenderCommandEncoder>)encoder {
    encoder.label = @"Lighting";
    [encoder setRenderPipelineState: _renderPipelineLighting];
    [encoder setCullMode: MTLCullModeBack];
    [encoder setVertexBuffer: _commonVertexBuffer
                      offset: 0
                     atIndex: 0];
    [encoder setFragmentBuffer: _lightPropsBuffer
                        offset: _currentBufferIndex * sizeof(light_t) * kNumLight
                       atIndex: 1];
    [encoder setFragmentBuffer: _lightGlobalBuffer
                        offset: _currentBufferIndex * sizeof(light_global_t)
                       atIndex: 2];
    [encoder setFragmentTexture: _gBuffer.normal
                        atIndex: attachment_normal];
    [encoder setFragmentTexture: _gBuffer.pos
                        atIndex: attachment_pos];
    [encoder setFragmentTexture: _gBuffer.shading
                        atIndex: attachment_shading];
    [encoder setFragmentTexture: _gBuffer.tangent
                        atIndex: attachment_tangent];
    for(int i = 0; i < _numLights; i++) {
        if(_lights[i].castShadows) {
            MGPShadowBuffer *shadowBuffer = [_shadowManager newShadowBufferForLight: _lights[i]
                                                                         resolution: 512
                                                                      cascadeLevels: 1];
            [encoder setFragmentTexture: shadowBuffer.texture
                                atIndex: i+11];
        }
    }
    [encoder drawPrimitives: MTLPrimitiveTypeTriangle
                vertexStart: 0
                vertexCount: 6];
    
    [encoder endEncoding];
}

- (void)renderShading:(id<MTLRenderCommandEncoder>)encoder {
    encoder.label = @"Shading";
    [encoder setRenderPipelineState: _renderPipelineShading];
    [encoder setCullMode: MTLCullModeBack];
    [encoder setVertexBuffer: _commonVertexBuffer
                      offset: 0
                     atIndex: 0];
    [encoder setFragmentBuffer: _cameraPropsBuffer
                        offset: _currentBufferIndex * sizeof(camera_props_t)
                       atIndex: 1];
    [encoder setFragmentBuffer: _lightGlobalBuffer
                        offset: _currentBufferIndex * sizeof(light_global_t)
                       atIndex: 2];
    [encoder setFragmentTexture: _gBuffer.albedo
                        atIndex: attachment_albedo];
    [encoder setFragmentTexture: _gBuffer.normal
                        atIndex: attachment_normal];
    [encoder setFragmentTexture: _gBuffer.pos
                        atIndex: attachment_pos];
    [encoder setFragmentTexture: _gBuffer.shading
                        atIndex: attachment_shading];
    [encoder setFragmentTexture: _gBuffer.lighting
                        atIndex: attachment_light];
    if(_IBLs.count > 0) {
        [encoder setFragmentTexture: _IBLs[_renderingIBLIndex].irradianceMap
                            atIndex: attachment_irradiance];
        [encoder setFragmentTexture: _IBLs[_renderingIBLIndex].prefilteredSpecularMap
                            atIndex: attachment_prefiltered_specular];
        [encoder setFragmentTexture: _IBLs[_renderingIBLIndex].BRDFLookupTexture
                            atIndex: attachment_brdf_lookup];
    }
    [encoder setFragmentTexture: ((MGPPostProcessingLayerSSAO *)_postProcess[0]).ssaoTexture
                        atIndex: attachment_ssao];
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
    [encoder setFragmentTexture: _gBuffer.output
                        atIndex: 0];
    [encoder drawPrimitives: MTLPrimitiveTypeTriangle
                vertexStart: 0
                vertexCount: 6];
    
    [encoder endEncoding];
}

- (void)resize:(CGSize)newSize {
    [_gBuffer resize:newSize];
    [_postProcess resize:newSize];
    MGPProjectionState proj = _camera.projectionState;
    proj.aspectRatio = newSize.width / newSize.height;
    _camera.projectionState = proj;
    [self _initSkyboxDepthTexture];
}

@end
