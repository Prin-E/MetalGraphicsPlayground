//
//  DeferredRenderer.m
//  MetalPostProcessing
//
//  Created by 이현우 on 03/05/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import "DeferredRenderer.h"
#import "../Common/Shaders/SharedStructures.h"
#import "../Common/Shaders/LightingCommon.h"
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
#import "../Common/Sources/Model/MGPFrustum.h"
#import "../Common/Sources/Model/MGPBoundingVolume.h"
#import "../Common/Sources/Rendering/MGPGizmos.h"
#import "../Common/Sources/Utility/MGPTextureManager.h"

#define STB_IMAGE_IMPLEMENTATION
#import "../Common/STB/stb_image.h"

#ifndef LERP
#define LERP(x,y,t) ((x)*(1.0-(t))+(y)*(t))
#endif

const size_t kNumInstance = 1;
const uint32_t kNumLight = MAX_NUM_LIGHTS;
const float kLightIntensityBase = 1.0f;
const float kLightIntensityVariation = 1.0f;
const size_t kShadowResolution = 512;
const float kCameraSpeed = 1;
const size_t kLightCullBufferSize = 19881*4*16; // fits Pro Display XDR (6016/16)*(3384/16)/4=19881
const NSUInteger kLightCountPerDrawCall = 4;

#define DEG_TO_RAD(x) ((x)*0.0174532925)

@implementation DeferredRenderer {
    camera_props_t camera_props[kMaxBuffersInFlight];
    instance_props_t instance_props[kMaxBuffersInFlight * kNumInstance];
    light_t light_props[kMaxBuffersInFlight * kNumLight];
    light_global_t light_globals[kMaxBuffersInFlight];
    
    size_t _currentBufferIndex;
    float _elapsedTime;
    float _animationTime;
    
    BOOL _moveFlags[6];     // Front, Back, Left, Right, Up, Down
    BOOL _moveFast;
    float _moveSpeeds[6];   // same as flags
    NSPoint _mouseDelta, _prevMousePos;
    
    BOOL _mouseDown;
    MGPCamera *_camera;
    BOOL _isOrthographic;
    BOOL _drawGizmos;
    
    // props
    id<MTLBuffer> _cameraPropsBuffer;
    id<MTLBuffer> _instancePropsBuffer;
    id<MTLBuffer> _lightPropsBuffer;
    id<MTLBuffer> _lightGlobalBuffer;
    id<MTLBuffer> _lightShadowPropsBuffer;
    
    // common vertex buffer (quad + cube)
    id<MTLBuffer> _commonVertexBuffer;
    
    // g-buffer
    MGPGBuffer *_gBuffer;
    
    // image-based lighting
    NSMutableArray<MGPImageBasedLighting *> *_IBLs;
    NSInteger _currentIBLIndex, _renderingIBLIndex;
    
    // render pass, pipeline states
    id<MTLRenderPipelineState> _renderPipelineSkybox;
    id<MTLRenderPipelineState> _renderPipelineLighting;
    id<MTLRenderPipelineState> _renderPipelineIndirectLighting;
    id<MTLRenderPipelineState> _renderPipelineShading;
    id<MTLRenderPipelineState> _renderPipelinePresent;
    MTLRenderPassDescriptor *_renderPassSkybox;
    MTLRenderPassDescriptor *_renderPassPresent;
    id<MTLComputePipelineState> _computePipelineLightCulling;
    id<MTLRenderPipelineState> _renderPipelineLightCullTile;
    
    // depth-stencil
    id<MTLDepthStencilState> _depthStencil;
    
    // Meshes
    NSArray<MGPMesh *> *_meshes;
    
    // Lights
    NSMutableArray<MGPLight *> *_lights;
    id<MTLBuffer> _lightCullBuffer;
    
    // Post-processing
    MGPPostProcessing *_postProcess;
    MGPPostProcessingLayerSSAO *_ssao;
    MGPPostProcessingLayerScreenSpaceReflection *_ssr;
    
    // Shadow
    MGPShadowManager *_shadowManager;
    
    // Gizmos
    MGPGizmos *_gizmos;
    
    // Texture Manager
    MGPTextureManager *_textureManager;
}

- (void)setView:(MGPView *)view {
    [super setView:view];
    [view setDelegate:self];
}

- (void)view:(MGPView *)view keyDown:(NSEvent *)theEvent {
    if(theEvent.keyCode == 49) {
        // space key
        self.animate = !self.animate;
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
        NSLog(@"Orthographic : %d", _isOrthographic);
    }
    if(theEvent.keyCode == 18) {
        // 1
        _drawGizmos = !_drawGizmos;
        NSLog(@"Gizmo : %d", _drawGizmos);
    }
    if(theEvent.keyCode == 19) {
        // 2
        self.cullOn = !self.cullOn;
        NSLog(@"Cull : %d", self.cullOn);
    }
    if(theEvent.keyCode == 20) {
        // 2
        self.locksFrustum = !self.locksFrustum;
        NSLog(@"Frustum Lock : %d", self.locksFrustum);
    }
    if(theEvent.keyCode == 49) {
        // space
        NSLog(@"camera (%.3f, %.3f, %.3f)", _camera.position.x, _camera.position.y, _camera.position.z);
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
        _roughness = 1.0f;
        _metalic = 0.0f;
        self.numLights = 64;
        self.cullOn = YES;
        self.ssaoIntensity = 1.0f;
        self.ssaoNumSamples = 32;
        self.ssaoRadius = 1.0f;
        self.attenuation = 0.5f;
        self.vignette = 0.25f;
        self.lightGridTileSize = 16;
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
    NSArray<NSString*> *skyboxNames = @[@"Milkyway_small"];
    for(NSInteger i = 0; i < skyboxNames.count; i++) {
        NSString *skyboxImagePath = [[NSBundle mainBundle] pathForResource:skyboxNames[i]
                                                                    ofType:@"hdr"];
        int skyboxWidth, skyboxHeight, skyboxComps;
        float* skyboxImageData = stbi_loadf(skyboxImagePath.UTF8String, &skyboxWidth, &skyboxHeight, &skyboxComps, 4);
        
        MTLTextureDescriptor *skyboxTextureDescriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA32Float
                                                                                                           width:skyboxWidth
                                                                                                          height:skyboxHeight
                                                                                                       mipmapped:NO];
        
        // Create intermediate texture for upload
        id<MTLTexture> skyboxIntermediateTexture = [self.device newTextureWithDescriptor: skyboxTextureDescriptor];
        [skyboxIntermediateTexture replaceRegion:MTLRegionMake2D(0, 0, skyboxWidth, skyboxHeight)
                         mipmapLevel:0
                           withBytes:skyboxImageData
                         bytesPerRow:16*skyboxWidth];
        stbi_image_free(skyboxImageData);
        
        // Create GPU-only texture and blit pixels
        skyboxTextureDescriptor.usage = MTLTextureUsageShaderRead;
        skyboxTextureDescriptor.storageMode = MTLStorageModePrivate;
        id<MTLTexture> skyboxTexture = [self.device newTextureWithDescriptor: skyboxTextureDescriptor];
        id<MTLCommandBuffer> blitBuffer = [self.queue commandBuffer];
        id<MTLBlitCommandEncoder> blit = [blitBuffer blitCommandEncoder];
        [blit copyFromTexture:skyboxIntermediateTexture
                  sourceSlice:0
                  sourceLevel:0
                 sourceOrigin:MTLOriginMake(0, 0, 0)
                   sourceSize:MTLSizeMake(skyboxWidth, skyboxHeight, 1)
                    toTexture:skyboxTexture
             destinationSlice:0
             destinationLevel:0
            destinationOrigin:MTLOriginMake(0, 0, 0)];
        [blit endEncoding];
        [blitBuffer commit];
        [blitBuffer waitUntilCompleted];
        
        MGPImageBasedLighting *IBL = [[MGPImageBasedLighting alloc] initWithDevice: self.device
                                                                           library: self.defaultLibrary
                                                                equirectangularMap: skyboxTexture];
        [_IBLs addObject: IBL];
    }
    
    // vertex descriptor
    MDLVertexDescriptor *mdlVertexDescriptor = MTKModelIOVertexDescriptorFromMetal(_gBuffer.baseVertexDescriptor);
    mdlVertexDescriptor.attributes[attrib_pos].name = MDLVertexAttributePosition;
    mdlVertexDescriptor.attributes[attrib_uv].name = MDLVertexAttributeTextureCoordinate;
    mdlVertexDescriptor.attributes[attrib_normal].name = MDLVertexAttributeNormal;
    mdlVertexDescriptor.attributes[attrib_tangent].name = MDLVertexAttributeTangent;
    
    // meshes
    _meshes = [MGPMesh loadMeshesFromURL: [[NSBundle mainBundle] URLForResource: @"sponza"
                                                                  withExtension: @"obj"]
                 modelIOVertexDescriptor: mdlVertexDescriptor
                                  device: self.device
                        calculateNormals: NO
                                   error: nil];
    
    // build render pipeline
    MTLRenderPipelineDescriptor *renderPipelineDescriptorPresent = [[MTLRenderPipelineDescriptor alloc] init];
    renderPipelineDescriptorPresent.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm_sRGB;
    renderPipelineDescriptorPresent.colorAttachments[0].blendingEnabled = YES;
    renderPipelineDescriptorPresent.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
    renderPipelineDescriptorPresent.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    renderPipelineDescriptorPresent.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorOne;
    renderPipelineDescriptorPresent.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOne;
    renderPipelineDescriptorPresent.vertexFunction = [self.defaultLibrary newFunctionWithName: @"screen_vert"];
    renderPipelineDescriptorPresent.fragmentFunction = [self.defaultLibrary newFunctionWithName: @"screen_frag"];
    _renderPipelinePresent = [self.device newRenderPipelineStateWithDescriptor: renderPipelineDescriptorPresent
                                                                         error: nil];
    
    MTLRenderPipelineDescriptor *renderPipelineDescriptorSkybox = [[MTLRenderPipelineDescriptor alloc] init];
    renderPipelineDescriptorSkybox.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm_sRGB;
    renderPipelineDescriptorSkybox.vertexFunction = [self.defaultLibrary newFunctionWithName: @"skybox_vert"];
    renderPipelineDescriptorSkybox.fragmentFunction = [self.defaultLibrary newFunctionWithName: @"skybox_frag"];
    //renderPipelineDescriptorSkybox.depthAttachmentPixelFormat = _gBuffer.depth.pixelFormat;
    _renderPipelineSkybox = [self.device newRenderPipelineStateWithDescriptor: renderPipelineDescriptorSkybox
                                                                        error: nil];
    
    MTLRenderPipelineDescriptor *renderPipelineDescriptorLightCullTile = [[MTLRenderPipelineDescriptor alloc] init];
    renderPipelineDescriptorLightCullTile.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm_sRGB;
    renderPipelineDescriptorLightCullTile.colorAttachments[0].blendingEnabled = YES;
    renderPipelineDescriptorLightCullTile.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
    renderPipelineDescriptorLightCullTile.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    renderPipelineDescriptorLightCullTile.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorOne;
    renderPipelineDescriptorLightCullTile.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorOne;
    renderPipelineDescriptorLightCullTile.vertexFunction = [self.defaultLibrary newFunctionWithName: @"screen_vert"];
    renderPipelineDescriptorLightCullTile.fragmentFunction = [self.defaultLibrary newFunctionWithName: @"lightcull_frag"];
    _renderPipelineLightCullTile = [self.device newRenderPipelineStateWithDescriptor: renderPipelineDescriptorLightCullTile
                                                                         error: nil];
    
    // render pass
    _renderPassSkybox = [[MTLRenderPassDescriptor alloc] init];
    _renderPassSkybox.colorAttachments[0].loadAction = MTLLoadActionClear;
    _renderPassSkybox.colorAttachments[0].storeAction = MTLStoreActionStore;
    _renderPassSkybox.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0);
    //_renderPassSkybox.depthAttachment.loadAction = MTLLoadActionClear;
    //_renderPassSkybox.depthAttachment.storeAction = MTLStoreActionStore;
    
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
    
    // light culling
    _lightCullBuffer = [self.device newBufferWithLength: kLightCullBufferSize
                                                options:MTLResourceStorageModePrivate];
    _computePipelineLightCulling = [self.device newComputePipelineStateWithFunction: [self.defaultLibrary newFunctionWithName: @"cull_lights"]
                                                                              error: nil];
    
    // light shadow
    _lightShadowPropsBuffer = [self.device newBufferWithLength: sizeof(light_t)
                                                       options: MTLResourceStorageModeManaged];
    
    // camera
    _camera = [[MGPCamera alloc] init];
    _camera.position = simd_make_float3(0, 0.5, -0.6);
    
    // projection
    MGPProjectionState projection = _camera.projectionState;
    projection.aspectRatio = _gBuffer.size.width / _gBuffer.size.height;
    projection.fieldOfView = DEG_TO_RAD(60.0);
    projection.nearPlane = 0.1f;
    projection.farPlane = 30.0f;
    projection.orthographicSize = 5;
    _camera.projectionState = projection;
    
    // texture manager
    _textureManager = [[MGPTextureManager alloc] initWithDevice:self.device];
    
    // shadow
    _shadowManager = [[MGPShadowManager alloc] initWithDevice: self.device
                                                      library: self.defaultLibrary
                                             vertexDescriptor: _gBuffer.baseVertexDescriptor];
    
    // post-process
    _postProcess = [[MGPPostProcessing alloc] initWithDevice: self.device
                                                     library: self.defaultLibrary
                                              textureManager:_textureManager];
    _postProcess.gBuffer = _gBuffer;
    _postProcess.cameraBuffer = _cameraPropsBuffer;
    MGPPostProcessingLayerSSAO *ssao = [[MGPPostProcessingLayerSSAO alloc] initWithDevice: self.device
                                                                                 library: self.defaultLibrary];
    ssao.bias = 0.02f;
    [_postProcess addLayer: ssao];
    MGPPostProcessingLayerScreenSpaceReflection *ssr = [[MGPPostProcessingLayerScreenSpaceReflection alloc] initWithDevice:self.device
                                                                                                                   library:self.defaultLibrary];
    ssr.step = 1.0;
    ssr.iteration = 32;
    ssr.opacity = 1.0;
    [_postProcess addLayer: ssr];
    [_postProcess resize: _gBuffer.size];
    _ssao = ssao;
    _ssr = ssr;
    
    _gizmos = [[MGPGizmos alloc] initWithDevice:self.device
                                        library:self.defaultLibrary
                                  gizmoCapacity:8
                              maxBuffersInFight:kMaxBuffersInFlight];
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
    _ssao.enabled = _ssaoOn;
    _ssao.intensity = _ssaoIntensity;
    _ssao.numSamples = (uint32_t)_ssaoNumSamples;
    _ssao.radius = _ssaoRadius;
    _ssr.enabled = _ssrOn;
    _ssr.vignette = _vignette;
    _ssr.attenuation = _attenuation;
}

- (void)_updateCamera: (float)deltaTime {
    // rotation
    if(_mouseDown) {
        NSPoint pixelMouseDelta = [self.view convertPointToBacking: _mouseDelta];
        simd_float3 rot = _camera.rotation;
        rot.y = rot.y + pixelMouseDelta.x / (0.5f * self.size.height) * M_PI_2;
        rot.x = MIN(MAX(rot.x - pixelMouseDelta.y / (0.5f * self.size.height) * M_PI_2, -M_PI*0.4), M_PI*0.4);
        _camera.rotation = rot;
    }
    
    // move
    static int columnIndices[] = { 2, 2, 0, 0, 1, 1 };
    simd_float4x4 rotationMatrix = _camera.cameraToWorldRotationMatrix;
    simd_float3 positionAdd = {};
    BOOL positionIsChanged = NO;
    for(int i = 0; i < 6; i++) {
        float sign = (i % 2) ? -1.0f : 1.0f;
        _moveSpeeds[i] = LERP(_moveSpeeds[i], _moveFlags[i] ? kCameraSpeed * (_moveFast ? 5.0f : 1.0f) : 0.0f, deltaTime * 14);
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
        p->model.columns[0].x = p->model.columns[1].y = p->model.columns[2].z = 0.01f;
        p->material.albedo = instance_albedo[i];
        p->material.roughness = self.roughness;
        p->material.metalic = self.metalic;
        p->material.anisotropy = self.anisotropy;
    }
    
    // Update lights
    static simd_float3 light_colors[kNumLight];
    static float light_intensities[kNumLight];
    static simd_float4 light_dirs[kNumLight];
    static simd_float3 light_positions[kNumLight];
    static BOOL init_light_value = NO;
    static uint32_t first_point_light_index = 1;
    if(!init_light_value) {
        init_light_value = YES;
        for(int i = 0; i < kNumLight; i++) {
            light_colors[i] = vector3(rand() / (float)RAND_MAX, rand() / (float)RAND_MAX, rand() / (float)RAND_MAX);
            light_intensities[i] = kLightIntensityBase + rand() / (float)RAND_MAX * kLightIntensityVariation;
            if(i >= first_point_light_index) {
                light_intensities[i] += rand() / (float)RAND_MAX;
            }
            light_dirs[i] = simd_normalize(vector4(rand() / (float)RAND_MAX - 0.5f,
                                                   -rand() / (float)RAND_MAX - 0.25f,
                                                   rand() / (float)RAND_MAX - 0.5f, 0.0f));
            light_positions[i] = simd_make_float3(-11.0f + 0.333f * i,
                                                  0.5f + 0.5f * (i % 2),
                                                  -2.0f + 2.0f * (i % 4));
        }
    }
    
    light_globals[_currentBufferIndex].num_light = _numLights;
    light_globals[_currentBufferIndex].first_point_light_index = first_point_light_index;
    light_globals[_currentBufferIndex].ambient_color = _IBLOn ? simd_make_float3(0, 0, 0) : simd_make_float3(0.1f, 0.1f, 0.1f);
    light_globals[_currentBufferIndex].light_projection = matrix_from_perspective_fov_aspectLH(DEG_TO_RAD(60.0f), _gBuffer.size.width / _gBuffer.size.height, 1.0f, 80.0f);
    light_globals[_currentBufferIndex].tile_size = _lightGridTileSize;
    
    for(NSInteger i = 0; i < _numLights; i++) {
        simd_float3 rot_dir = vector3(0.0f, 1.0f, 0.0f);
        simd_float4 dir = matrix_multiply(matrix_from_rotation(_animationTime, rot_dir.x, rot_dir.y, rot_dir.z), light_dirs[i]);
        
        // set light properties
        MGPLight *light = _lights[i];
        light.color = light_colors[i];
        light.intensity = light_intensities[i];
        light.direction = simd_make_float3(dir);
        
        // [first_point_light_index] dir.light, [MAX_NUM_LIGHTS - first_point_light_index] point light
        if(i < first_point_light_index) {
            light.position = -light.direction * 30.0f;
            light.castShadows = YES;
            light.shadowBias = 0.001f;
            light.type = MGPLightTypeDirectional;
        }
        else {
            light.position = light_positions[i] +
            simd_make_float3(0.5 * sinf(M_PI * (_animationTime + light_colors[i].x)),
                             0.5 * sinf(M_PI * (_animationTime + light_colors[i].x)),
                             0.5 * sinf(M_PI * (_animationTime + light_colors[i].z)));
            light.intensity += light_colors[i].y * 2.5f;
            light.radius = 2.0f + light_colors[i].z;
            light.type = MGPLightTypePoint;
        }
        
        // light properties -> buffer
        light_t *light_props_ptr = &light_props[_currentBufferIndex * kNumLight + i];
        *light_props_ptr = light.shaderProperties;
        light_props_ptr->light_view_projection = simd_mul(light_globals[_currentBufferIndex].light_projection, light_props_ptr->light_view);
    }
    for(NSUInteger i = _numLights; i < kNumLight; i++) {
        _lights[i].intensity = 0;
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
    if(_IBLOn) {
        if(_IBLs[_currentIBLIndex].isAnyRenderingRequired) {
            [self performPrefilterPass];
        }
        else {
            _renderingIBLIndex = _currentIBLIndex;
        }
    }
    
    [self performRenderingPassWithCompletionHandler:^{
        [self signal];
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
    
    [self beginGPUTime:commandBuffer];
    
    // prepare gizmo encoding
    [_gizmos prepareEncodingWithColorTexture:_gBuffer.output
                                depthTexture:_gBuffer.depth
                                cameraBuffer:_cameraPropsBuffer
                                 bufferIndex:_currentBufferIndex];
    
    // skybox pass
    if(_IBLOn) {
        _renderPassSkybox.colorAttachments[0].texture = self.view.currentDrawable.texture;
        id<MTLRenderCommandEncoder> skyboxPassEncoder = [commandBuffer renderCommandEncoderWithDescriptor: _renderPassSkybox];
        [self renderSkybox:skyboxPassEncoder];
    }
    
    // Post-process before prepass
    [_postProcess render: commandBuffer
       forRenderingOrder: MGPPostProcessingRenderingOrderBeforePrepass];
    
    // G-buffer prepass
    MGPGBufferAttachmentType prePassAttachments = MGPGBufferAttachmentTypeAlbedo;
    prePassAttachments |= MGPGBufferAttachmentTypeNormal;
    prePassAttachments |= MGPGBufferAttachmentTypeShading;
    prePassAttachments |= MGPGBufferAttachmentTypeDepth;
    if(_anisotropyOn)
        prePassAttachments |= MGPGBufferAttachmentTypeTangent;
    id<MTLRenderCommandEncoder> prepassEncoder = [commandBuffer renderCommandEncoderWithDescriptor: [_gBuffer prePassDescriptorWithAttachment:prePassAttachments]];
    [self renderGBuffer:prepassEncoder];
     
    // Shadowmap Passes
    [self renderShadows: commandBuffer];
    
    // Post-process before light pass
    [_postProcess render: commandBuffer
       forRenderingOrder: MGPPostProcessingRenderingOrderBeforeLightPass];
    
    if(_lightCullOn) {
        // Light cull pass
        id<MTLComputeCommandEncoder> lightCullPassEncoder = [commandBuffer computeCommandEncoder];
        [self computeLightCullGrid:lightCullPassEncoder];
    }
    else {
        // G-buffer light-accumulation pass
        // render 4 lights per each draw call
        id<MTLRenderCommandEncoder> lightingPassEncoder = [commandBuffer renderCommandEncoderWithDescriptor: _gBuffer.lightingPassBaseDescriptor];
        [self renderLighting:lightingPassEncoder
                   fromIndex:0
                     toIndex:MIN(_numLights,kLightCountPerDrawCall)-1
            countPerDrawCall:kLightCountPerDrawCall];
        if(_numLights > kLightCountPerDrawCall) {
            lightingPassEncoder = [commandBuffer renderCommandEncoderWithDescriptor: _gBuffer.lightingPassAddDescriptor];
            [self renderLighting:lightingPassEncoder
                       fromIndex:kLightCountPerDrawCall
                         toIndex:_numLights-1
                countPerDrawCall:kLightCountPerDrawCall];
        }
    }
    
    // Post-process before shade pass
    [_postProcess render: commandBuffer
       forRenderingOrder: MGPPostProcessingRenderingOrderBeforeShadePass];
    
    // G-buffer shade pass
    id<MTLRenderCommandEncoder> shadingPassEncoder = [commandBuffer renderCommandEncoderWithDescriptor: _gBuffer.shadingPassDescriptor];
    [self renderShading:shadingPassEncoder];
    
    if(_lightCullOn) {
        // Directional lighting (with shadow) pass
        id<MTLRenderCommandEncoder> directionalShadowedLightingPassEncoder = [commandBuffer renderCommandEncoderWithDescriptor:_gBuffer.directionalShadowedLightingPassDescriptor];
        [self renderDirectionalShadowedLighting:directionalShadowedLightingPassEncoder];
        
        // Indirect lighting pass
        id<MTLRenderCommandEncoder> indirectLightingPassEncoder = [commandBuffer renderCommandEncoderWithDescriptor:_gBuffer.indirectLightingPassDescriptor];
        [self renderIndirectLighting:indirectLightingPassEncoder];
    }
    
    // Post-process after shade pass
    [_postProcess render: commandBuffer
       forRenderingOrder: MGPPostProcessingRenderingOrderAfterShadePass];
    
    // Encode gizmos
    [_gizmos encodeToCommandBuffer: commandBuffer];
    
    // present to framebuffer
    _renderPassPresent.colorAttachments[0].texture = self.view.currentDrawable.texture;
    if(_IBLOn)
        _renderPassPresent.colorAttachments[0].loadAction = MTLLoadActionLoad;
    else
        _renderPassPresent.colorAttachments[0].loadAction = MTLLoadActionClear;
    id<MTLRenderCommandEncoder> presentCommandEncoder = [commandBuffer renderCommandEncoderWithDescriptor: _renderPassPresent];
    [self renderFramebuffer:presentCommandEncoder];
    
    // present
    [commandBuffer presentDrawable: self.view.currentDrawable];
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer) {
        if(handler != nil)
            handler();
    }];
    
    // calculate GPU time
    if(@available(macOS 10.15, *)) {
        static CGFloat elapsed = 0.0f;
        [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer) {
            [self endGPUTime:buffer];
            elapsed += self.GPUTime;
            if(elapsed >= 2.0f) {
                NSLog(@"GPU Time : %.2fms", (self.GPUTime) * 1000.0f);
                elapsed -= 2.0f;
            }
        }];
    }
    
    [commandBuffer commit];
}

- (void)renderSkybox:(id<MTLRenderCommandEncoder>)encoder {
    encoder.label = @"Skybox";
    [encoder setRenderPipelineState: _renderPipelineSkybox];
    //[encoder setDepthStencilState: _depthStencil];
    [encoder setCullMode: MTLCullModeBack];

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
    
    [encoder endEncoding];
}

- (void)renderObjects:(id<MTLRenderCommandEncoder>)encoder
         bindTextures:(BOOL)bindTextures
              frustum:(MGPFrustum *)frustum {
    MGPFrustum *localSpaceFrustum = [frustum frustumByMultipliedWithMatrix:simd_inverse(instance_props[_currentBufferIndex * kNumInstance].model)];
    
    id<MTLTexture> textures[tex_total] = {};
    BOOL textureChangedFlags[tex_total] = {};
    for(int i = 0; i < tex_total; i++) {
        textureChangedFlags[i] = YES;
    }
    
    id<MTLRenderPipelineState> prevPrepassPipeline = nil;
    for(MGPMesh *mesh in _meshes) {
        // Set vertex buffer
        [encoder setVertexBuffer: mesh.metalKitMesh.vertexBuffers[0].buffer
                          offset: 0
                         atIndex: 0];
        
        // draw submeshes
        for(MGPSubmesh *submesh in mesh.submeshes) {
            id<MGPBoundingVolume> volume = submesh.volume;
            
            // Culling
            if(_cullOn) {
                if([volume isCulledInFrustum:localSpaceFrustum])
                    continue;
            }
            
            // Gizmo
            if(bindTextures && _drawGizmos) {
                // TODO: needs more sophiscated local to world translation...
                
                if([volume class] == [MGPBoundingSphere class]) {
                    MGPBoundingSphere *sphere = volume;
                    simd_float3 world_pos = sphere.position * 0.01f;
                    float world_radius = sphere.radius * 0.01f;
                    [_gizmos drawWireframeSphereWithCenter:world_pos
                                                    radius:world_radius];
                }
                else if([volume class] == [MGPBoundingBox class]) {
                    MGPBoundingBox *box = volume;
                    simd_float3 world_pos = box.position * 0.01f;
                    simd_float3 world_extent = box.extent * 0.01f;
                    [_gizmos drawWireframeBoxWithCenter:world_pos
                                                 extent:world_extent];
                }
            }
            
            // Texture binding
            if(bindTextures) {
                // Check previous draw call's textures and current textures are duplicated.
                for(int i = 0; i < tex_total; i++) {
                    id<MTLTexture> texture = submesh.textures[i];
                    if(texture == (id<MTLTexture>)NSNull.null)
                        texture = nil;
                    if(textures[i] != texture) {
                        textureChangedFlags[i] = YES;
                        textures[i] = texture;
                    }
                }
                
                // Set textures
                for(int i = 0; i < tex_total; i++) {
                    if(textureChangedFlags[i]) {
                        [encoder setFragmentTexture: textures[i] atIndex: i];
                        textureChangedFlags[i] = NO;
                    }
                }
                
                // Set render pipeline for G-buffer
                MGPGBufferPrepassFunctionConstants prepassConstants = {};
                prepassConstants.hasAlbedoMap = submesh.textures[tex_albedo] != NSNull.null;
                prepassConstants.hasNormalMap = submesh.textures[tex_normal] != NSNull.null;
                prepassConstants.hasRoughnessMap = submesh.textures[tex_roughness] != NSNull.null;
                prepassConstants.hasMetalicMap = submesh.textures[tex_metalic] != NSNull.null;
                prepassConstants.hasOcclusionMap = submesh.textures[tex_occlusion] != NSNull.null;
                prepassConstants.hasAnisotropicMap = submesh.textures[tex_anisotropic] != NSNull.null;
                prepassConstants.flipVertically = YES;  // for sponza textures
                prepassConstants.sRGBTexture = YES;     // for sponza textures
                prepassConstants.usesAnisotropy = _anisotropyOn;

                MGPGBufferAttachmentType prePassAttachments = MGPGBufferAttachmentTypeAlbedo;
                prePassAttachments |= MGPGBufferAttachmentTypeNormal;
                prePassAttachments |= MGPGBufferAttachmentTypeShading;
                prePassAttachments |= MGPGBufferAttachmentTypeDepth;
                if(_anisotropyOn)
                    prePassAttachments |= MGPGBufferAttachmentTypeTangent;
                
                id<MTLRenderPipelineState> prepassPipeline = [_gBuffer renderPipelineStateWithConstants: prepassConstants
                                                                                            attachments: prePassAttachments
                                                                                                  error: nil];
                if(prepassPipeline != nil &&
                   prevPrepassPipeline != prepassPipeline) {
                    [encoder setRenderPipelineState: prepassPipeline];
                    prevPrepassPipeline = prepassPipeline;
                }
            }
            
            // Draw call
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
    
    static MGPFrustum *frustum = nil;
    if(_locksFrustum) {
        if(_camera.frustum == frustum)
            frustum = nil;
        if(frustum == nil)
            frustum = [_camera.frustum frustumByMultipliedWithMatrix:matrix_identity_float4x4];
    }
    else {
        frustum = _camera.frustum;
    }
    
    [self renderObjects: encoder
           bindTextures: YES
                frustum: frustum];
    [encoder endEncoding];
}

- (void)renderShadows:(id<MTLCommandBuffer>)buffer {
    if(_numLights == 0) return;
    
    for(int i = 0; i < _numLights; i++) {
        if(_lights[i].castShadows) {
            light_t lightProps = _lights[i].shaderProperties;
            lightProps.light_view_projection = simd_mul(light_globals[_currentBufferIndex].light_projection, lightProps.light_view);
            memcpy(_lightShadowPropsBuffer.contents, &lightProps, sizeof(light_t));
            [_lightShadowPropsBuffer didModifyRange:NSMakeRange(0, sizeof(light_t))];
            
            MGPShadowBuffer *shadowBuffer = [_shadowManager newShadowBufferForLight: _lights[i]
                                                                         resolution: kShadowResolution
                                                                      cascadeLevels: 1];
            
            if(shadowBuffer != nil) {
                id<MTLRenderCommandEncoder> encoder = [buffer renderCommandEncoderWithDescriptor: shadowBuffer.shadowPass];
                encoder.label = [NSString stringWithFormat: @"Shadow #%d", i+1];
                [encoder setRenderPipelineState: _shadowManager.shadowPipeline];
                [encoder setDepthStencilState: _depthStencil];
                [encoder setCullMode: MTLCullModeBack];
                
                [encoder setVertexBuffer: _lightShadowPropsBuffer
                                  offset: 0
                                 atIndex: 1];
                [encoder setVertexBuffer: _lightGlobalBuffer
                                  offset: _currentBufferIndex * sizeof(light_global_t)
                                 atIndex: 2];
                [encoder setVertexBuffer: _instancePropsBuffer
                                  offset: _currentBufferIndex * sizeof(instance_props_t) * kNumInstance
                                 atIndex: 3];
                
                [self renderObjects: encoder
                       bindTextures: NO
                            frustum: _lights[i].frustum];
                [encoder endEncoding];
            }
        }
    }
}

- (void)renderLighting:(id<MTLRenderCommandEncoder>)encoder
             fromIndex:(NSUInteger)lightFromIndex
               toIndex:(NSUInteger)lightToIndex
      countPerDrawCall:(NSUInteger)lightCountPerDrawCall {
    MGPGBufferShadingFunctionConstants constants = {};
    constants.usesAnisotropy = _anisotropyOn;
    
    _renderPipelineLighting = [_gBuffer lightingPipelineStateWithConstants:constants
                                                                     error:nil];
    
    encoder.label = [NSString stringWithFormat: @"Lighting %@", lightFromIndex == 0 ? @"Base" : @"Add"];
    [encoder setRenderPipelineState: _renderPipelineLighting];
    [encoder setCullMode: MTLCullModeBack];
    [encoder setFragmentBuffer: _cameraPropsBuffer
                        offset: _currentBufferIndex * sizeof(camera_props_t)
                       atIndex: 0];
    [encoder setFragmentBuffer: _lightGlobalBuffer
                        offset: _currentBufferIndex * sizeof(light_global_t)
                       atIndex: 2];
    [encoder setFragmentTexture: _gBuffer.normal
                        atIndex: attachment_normal];
    [encoder setFragmentTexture: _gBuffer.shading
                        atIndex: attachment_shading];
    if(_anisotropyOn) {
        [encoder setFragmentTexture: _gBuffer.tangent
                            atIndex: attachment_tangent];
    }
    [encoder setFragmentTexture: _gBuffer.depth
                        atIndex: attachment_depth];
    
    for(NSUInteger i = lightFromIndex; i <= lightToIndex; i += lightCountPerDrawCall) {
        [encoder setFragmentBuffer: _lightPropsBuffer
                            offset: (_currentBufferIndex * kNumLight + i) * sizeof(light_t)
                           atIndex: 1];
        
        for(NSUInteger j = 0; j < lightCountPerDrawCall; j++) {
            if(_lights[i + j].castShadows) {
                MGPShadowBuffer *shadowBuffer = [_shadowManager newShadowBufferForLight: _lights[i + j]
                                                                             resolution: kShadowResolution
                                                                          cascadeLevels: 1];
                [encoder setFragmentTexture: shadowBuffer.texture
                                    atIndex: j+attachment_shadow_map];
            }
            else {
                [encoder setFragmentTexture: nil
                                    atIndex: j+attachment_shadow_map];
            }
        }
        [encoder drawPrimitives: MTLPrimitiveTypeTriangle
                    vertexStart: 0
                    vertexCount: 6];
    }
    
    [encoder endEncoding];
}

- (void)computeLightCullGrid:(id<MTLComputeCommandEncoder>)encoder {
    encoder.label = @"Light Culling";
    
    [encoder setComputePipelineState: _computePipelineLightCulling];
    NSUInteger tileSize = _lightGridTileSize;
    NSUInteger width = _gBuffer.size.width + 0.5;
    NSUInteger height = _gBuffer.size.height + 0.5;
    width = (width + tileSize - 1) / tileSize;
    height = (height + tileSize - 1) / tileSize;
    MTLSize threadSize = MTLSizeMake(width, height, 1);
    [encoder setBuffer: _lightCullBuffer
                offset: 0
               atIndex: 0];
    [encoder setBuffer: _lightPropsBuffer
                offset: _currentBufferIndex * sizeof(light_t) * kNumLight
               atIndex: 1];
    [encoder setBuffer: _lightGlobalBuffer
                offset: _currentBufferIndex * sizeof(light_global_t)
               atIndex: 2];
    [encoder setBuffer: _cameraPropsBuffer
                offset: _currentBufferIndex * sizeof(camera_props_t)
               atIndex: 3];
    [encoder setTexture: _gBuffer.depth
                atIndex: 0];
    [encoder dispatchThreadgroups:threadSize
            threadsPerThreadgroup:MTLSizeMake(tileSize, tileSize, 1)];
    [encoder endEncoding];
}

- (void)renderShading:(id<MTLRenderCommandEncoder>)encoder {
    MGPGBufferShadingFunctionConstants shadingConstants = {};
    shadingConstants.hasIBLIrradianceMap = _IBLOn;
    shadingConstants.hasIBLSpecularMap = _IBLOn;
    shadingConstants.hasSSAOMap = _ssaoOn;
    shadingConstants.usesAnisotropy = _anisotropyOn;
    
    if(_lightCullOn) {
        _renderPipelineShading = [_gBuffer shadingPipelineStateWithConstants: shadingConstants
                                                                       error: nil];
    }
    else {
        _renderPipelineShading = [_gBuffer nonLightCulledShadingPipelineStateWithConstants: shadingConstants
                                                                       error: nil];
    }
    
    encoder.label = @"Shading";
    [encoder setRenderPipelineState: _renderPipelineShading];
    [encoder setCullMode: MTLCullModeBack];
    [encoder setFragmentBuffer: _cameraPropsBuffer
                        offset: _currentBufferIndex * sizeof(camera_props_t)
                       atIndex: 0];
    [encoder setFragmentBuffer: _lightGlobalBuffer
                        offset: _currentBufferIndex * sizeof(light_global_t)
                       atIndex: 1];
    [encoder setFragmentBuffer: _lightPropsBuffer
                        offset: _currentBufferIndex * sizeof(light_t) * kNumLight
                       atIndex: 2];
    [encoder setFragmentBuffer: _lightCullBuffer
                        offset: 0
                       atIndex: 3];
    [encoder setFragmentTexture: _gBuffer.albedo
                        atIndex: attachment_albedo];
    [encoder setFragmentTexture: _gBuffer.normal
                        atIndex: attachment_normal];
    [encoder setFragmentTexture: _gBuffer.shading
                        atIndex: attachment_shading];
    if(_anisotropyOn) {
        [encoder setFragmentTexture: _gBuffer.tangent
                            atIndex: attachment_tangent];
    }
    [encoder setFragmentTexture: _gBuffer.depth
                        atIndex: attachment_depth];
    if(!_lightCullOn) {
        [encoder setFragmentTexture: _gBuffer.lighting
                            atIndex: attachment_light];
        if(_IBLOn) {
            [encoder setFragmentTexture: _IBLs[_renderingIBLIndex].irradianceMap
                                atIndex: attachment_irradiance];
            [encoder setFragmentTexture: _IBLs[_renderingIBLIndex].prefilteredSpecularMap
                                atIndex: attachment_prefiltered_specular];
            [encoder setFragmentTexture: _IBLs[_renderingIBLIndex].BRDFLookupTexture
                                atIndex: attachment_brdf_lookup];
        }
        if(_postProcess.layers.count > 0) {
            [encoder setFragmentTexture: ((MGPPostProcessingLayerSSAO *)_postProcess[0]).ssaoTexture
                                atIndex: attachment_ssao];
        }
    }
    [encoder drawPrimitives: MTLPrimitiveTypeTriangle
                vertexStart: 0
                vertexCount: 3];
    
    [encoder endEncoding];
}

- (void)renderIndirectLighting:(id<MTLRenderCommandEncoder>)encoder {
    MGPGBufferShadingFunctionConstants shadingConstants = {};
    shadingConstants.hasIBLIrradianceMap = _IBLOn;
    shadingConstants.hasIBLSpecularMap = _IBLOn;
    shadingConstants.hasSSAOMap = _ssaoOn;
    shadingConstants.usesAnisotropy = _anisotropyOn;
    
    _renderPipelineIndirectLighting = [_gBuffer indirectLightingPipelineStateWithConstants:shadingConstants
                                                                                     error:nil];
    
    encoder.label = @"Indirect Lighting";
    [encoder setRenderPipelineState: _renderPipelineIndirectLighting];
    [encoder setCullMode: MTLCullModeBack];
    [encoder setFragmentBuffer: _cameraPropsBuffer
                        offset: _currentBufferIndex * sizeof(camera_props_t)
                       atIndex: 0];
    [encoder setFragmentBuffer: _lightGlobalBuffer
                        offset: _currentBufferIndex * sizeof(light_global_t)
                       atIndex: 1];
    [encoder setFragmentTexture: _gBuffer.albedo
                        atIndex: attachment_albedo];
    [encoder setFragmentTexture: _gBuffer.normal
                        atIndex: attachment_normal];
    [encoder setFragmentTexture: _gBuffer.shading
                        atIndex: attachment_shading];
    if(_anisotropyOn) {
        [encoder setFragmentTexture: _gBuffer.tangent
                            atIndex: attachment_tangent];
    }
    [encoder setFragmentTexture: _gBuffer.depth
                        atIndex: attachment_depth];
    if(_IBLOn) {
        [encoder setFragmentTexture: _IBLs[_renderingIBLIndex].irradianceMap
                            atIndex: attachment_irradiance];
        [encoder setFragmentTexture: _IBLs[_renderingIBLIndex].prefilteredSpecularMap
                            atIndex: attachment_prefiltered_specular];
        [encoder setFragmentTexture: _IBLs[_renderingIBLIndex].BRDFLookupTexture
                            atIndex: attachment_brdf_lookup];
    }
    if(_postProcess.layers.count > 0) {
        [encoder setFragmentTexture: ((MGPPostProcessingLayerSSAO *)_postProcess[0]).ssaoTexture
                            atIndex: attachment_ssao];
    }
    [encoder drawPrimitives: MTLPrimitiveTypeTriangle
                vertexStart: 0
                vertexCount: 3];
    
    [encoder endEncoding];
}

- (void)renderDirectionalShadowedLighting:(id<MTLRenderCommandEncoder>)encoder {
    light_global_t lightGlobalProps = light_globals[_currentBufferIndex];
    MGPGBufferShadingFunctionConstants shadingConstants = {};
    shadingConstants.usesAnisotropy = _anisotropyOn;
    NSUInteger lightBufferOffset = _currentBufferIndex * sizeof(light_t) * MAX_NUM_LIGHTS;
    
    id<MTLRenderPipelineState> renderPipeline = [_gBuffer directionalShadowedLightingPipelineStateWithConstants:shadingConstants
                                                                                                          error:nil];

    encoder.label = @"Directional Shadowed Lighting";
    [encoder setRenderPipelineState: renderPipeline];
    [encoder setCullMode: MTLCullModeBack];
    [encoder setFragmentBuffer: _cameraPropsBuffer
                        offset: _currentBufferIndex * sizeof(camera_props_t)
                       atIndex: 0];
    [encoder setFragmentBuffer: _lightGlobalBuffer
                        offset: _currentBufferIndex * sizeof(light_global_t)
                       atIndex: 1];
    [encoder setFragmentBuffer: _lightPropsBuffer
                        offset: lightBufferOffset
                       atIndex: 2];
    [encoder setFragmentTexture: _gBuffer.albedo
                        atIndex: attachment_albedo];
    [encoder setFragmentTexture: _gBuffer.normal
                        atIndex: attachment_normal];
    [encoder setFragmentTexture: _gBuffer.shading
                        atIndex: attachment_shading];
    if(_anisotropyOn) {
        [encoder setFragmentTexture: _gBuffer.tangent
                            atIndex: attachment_tangent];
    }
    [encoder setFragmentTexture: _gBuffer.depth
                        atIndex: attachment_depth];
    
    for(NSUInteger i = 0; i < lightGlobalProps.first_point_light_index; i++) {
        if(light_props[i].cast_shadow) {
            MGPShadowBuffer *shadowBuffer = [_shadowManager newShadowBufferForLight:_lights[i]
                                                                         resolution: kShadowResolution
                                                                      cascadeLevels: 1];
            if(shadowBuffer) {
                [encoder pushDebugGroup:[NSString stringWithFormat:@"Directional Light #%lu", i+1]];
                [encoder setFragmentBufferOffset:lightBufferOffset + i * sizeof(light_t)
                                         atIndex:2];
                [encoder setFragmentTexture: shadowBuffer.texture
                                    atIndex: attachment_shadow_map];
                [encoder drawPrimitives: MTLPrimitiveTypeTriangle
                            vertexStart: 0
                            vertexCount: 3];
                [encoder popDebugGroup];
            }

        }
    }
    
    [encoder endEncoding];
}


- (void)renderFramebuffer:(id<MTLRenderCommandEncoder>)encoder {
    encoder.label = @"Present";
    
    if(_gBufferIndex == 6) {
        // Draw light-culling tiles
        [encoder setRenderPipelineState: _renderPipelineLightCullTile];
        [encoder setFragmentBuffer: _lightCullBuffer
                            offset: 0
                           atIndex: 0];
        [encoder setFragmentBuffer: _lightGlobalBuffer
                            offset: _currentBufferIndex * sizeof(light_global_t)
                           atIndex: 1];
    }
    else {
        [encoder setRenderPipelineState: _renderPipelinePresent];
    }
    
    [encoder setCullMode: MTLCullModeBack];
    [encoder setFragmentTexture: [self _presentationGBuferTexture]
                        atIndex: 0];
    [encoder drawPrimitives: MTLPrimitiveTypeTriangle
                vertexStart: 0
                vertexCount: 6];
    
    [encoder endEncoding];
}

- (id<MTLTexture>)_presentationGBuferTexture {
    switch(_gBufferIndex) {
        case 1:
            return _gBuffer.albedo;
        case 2:
            return _gBuffer.normal;
        case 3:
            return _gBuffer.tangent;
        case 4:
            return _gBuffer.shading;
        case 5:
            return _ssao.ssaoTexture;
        default:
            return _gBuffer.output;
    }
}

- (void)resize:(CGSize)newSize {
    [super resize:newSize];
    
    CGSize scaledSize = self.scaledSize;
    [_textureManager clearUnusedTemporaryTextures];
    [_gBuffer resize:scaledSize];
    [_postProcess resize:scaledSize];
    MGPProjectionState proj = _camera.projectionState;
    proj.aspectRatio = scaledSize.width / scaledSize.height;
    _camera.projectionState = proj;
}

@end
