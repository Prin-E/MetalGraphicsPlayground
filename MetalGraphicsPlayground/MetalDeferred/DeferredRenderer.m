//
//  DeferredRenderer.m
//  MetalDeferred
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
#import "../Common/Sources/Model/MGPShadowBuffer.h"
#import "../Common/Sources/Model/MGPShadowManager.h"
#import "../Common/Sources/Model/MGPLight.h"

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
    NSMutableArray<MGPImageBasedLighting *> *_IBLs;
    NSInteger _currentIBLIndex, _renderingIBLIndex;
    BOOL _renderIrradiance;
    
    // render pass, pipeline states
    id<MTLRenderPipelineState> _renderPipelineSkybox;
    id<MTLRenderPipelineState> _renderPipelinePrepass;
    id<MTLRenderPipelineState> _renderPipelinePrepassTest;
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
    NSArray<MGPMesh *> *_testObjects;
    
    // Lights
    NSMutableArray<MGPLight *> *_lights;
    
    // Shadow
    MGPShadowManager *_shadowManager;
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
    if(theEvent.keyCode == 18) {
        // 1
        _currentIBLIndex = 0;
    }
    if(theEvent.keyCode == 19) {
        // 2
        _currentIBLIndex = 1;
    }
    if(theEvent.keyCode == 20) {
        // 3
        _currentIBLIndex = 2;
    }
    if(theEvent.keyCode == 21) {
        // 4
        _currentIBLIndex = 3;
    }
    if(theEvent.keyCode == 23) {
        // 5
        _currentIBLIndex = 4;
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
        _numLights = 1;
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
    NSArray<NSString*> *skyboxNames = @[@"bush_restaurant_1k", @"Tropical_Beach_3k", @"Factory_Catwalk_2k",
                                        @"Milkyway_small", @"WinterForest_Ref"];
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
    
    // vertex descriptor
    MDLVertexDescriptor *mdlVertexDescriptor = MTKModelIOVertexDescriptorFromMetal(_gBuffer.baseVertexDescriptor);
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
    
    MGPTextureLoader *textureLoader = [[MGPTextureLoader alloc] initWithDevice: self.device];
    MDLMesh *mdlMesh = [MDLMesh newEllipsoidWithRadii: vector3(10.0f, 10.0f, 10.0f)
                                       radialSegments: 32
                                     verticalSegments: 32
                                         geometryType: MDLGeometryTypeTriangles
                                        inwardNormals: NO
                                           hemisphere: NO
                                            allocator: [[MTKMeshBufferAllocator alloc] initWithDevice: self.device]];
     
    mdlMesh.vertexDescriptor = mdlVertexDescriptor;
    MGPMesh *mesh = [[MGPMesh alloc] initWithModelIOMesh: mdlMesh
                                 modelIOVertexDescriptor: mdlVertexDescriptor
                                           textureLoader: textureLoader
                                                  device: self.device
                                        calculateNormals: NO
                                                   error: nil];
    
    mesh.submeshes[0].textures[tex_albedo] = [textureLoader newTextureFromURL: [[NSBundle mainBundle] URLForResource: @"albedo" withExtension: @"png"]
                                                                        usage: MTLTextureUsageShaderRead
                                                                  storageMode: MTLStorageModePrivate
                                                                        error: nil];
    mesh.submeshes[0].textures[tex_normal] = [textureLoader newTextureFromURL: [[NSBundle mainBundle] URLForResource: @"normal" withExtension: @"png"]
                                                                        usage: MTLTextureUsageShaderRead
                                                                  storageMode: MTLStorageModePrivate
                                                                        error: nil];
    mesh.submeshes[0].textures[tex_roughness] = [textureLoader newTextureFromURL: [[NSBundle mainBundle] URLForResource: @"roughness" withExtension: @"png"]
                                                                        usage: MTLTextureUsageShaderRead
                                                                  storageMode: MTLStorageModePrivate
                                                                        error: nil];
    mesh.submeshes[0].textures[tex_metalic] = [textureLoader newTextureFromURL: [[NSBundle mainBundle] URLForResource: @"metallic" withExtension: @"png"]
                                                                        usage: MTLTextureUsageShaderRead
                                                                  storageMode: MTLStorageModePrivate
                                                                        error: nil];
    mesh.submeshes[0].textures[tex_occlusion] = [textureLoader newTextureFromURL: [[NSBundle mainBundle] URLForResource: @"ao" withExtension: @"png"]
                                                                           usage: MTLTextureUsageShaderRead
                                                                     storageMode: MTLStorageModePrivate
                                                                           error: nil];
    /*
    mesh.submeshes[0].textures[tex_anisotropic] = [textureLoader newTextureFromURL: [[NSBundle mainBundle] URLForResource: @"AnisoDirection1" withExtension: @"jpg"]
                                                                           usage: MTLTextureUsageShaderRead
                                                                     storageMode: MTLStorageModePrivate
                                                                           error: nil];
     */
    
    _testObjects = @[ mesh ];
    
    // build render pipeline
    MGPGBufferPrepassFunctionConstants prepassConstants = {};
    prepassConstants.hasAlbedoMap = _meshes[0].submeshes[0].textures[tex_albedo] != NSNull.null;
    prepassConstants.hasNormalMap = NO;
    prepassConstants.hasRoughnessMap = _meshes[0].submeshes[0].textures[tex_roughness] != NSNull.null;
    prepassConstants.hasMetalicMap = _meshes[0].submeshes[0].textures[tex_metalic] != NSNull.null;
    prepassConstants.hasOcclusionMap = _meshes[0].submeshes[0].textures[tex_occlusion] != NSNull.null;
    prepassConstants.hasAnisotropicMap = _meshes[0].submeshes[0].textures[tex_anisotropic] != NSNull.null;
    prepassConstants.flipVertically = NO;
    MGPGBufferShadingFunctionConstants shadingConstants = {};
    shadingConstants.hasIBLIrradianceMap = _IBLs.count > 0;
    shadingConstants.hasIBLSpecularMap = _IBLs.count > 0;
    shadingConstants.hasSSAOMap = NO;
    _renderPipelinePrepass = [_gBuffer renderPipelineStateWithConstants: prepassConstants
                                                                  error: nil];
    _renderPipelineLighting = [_gBuffer lightingPipelineStateWithError: nil];
    _renderPipelineShading = [_gBuffer shadingPipelineStateWithConstants: shadingConstants
                                                                   error: nil];
    
    MGPGBufferPrepassFunctionConstants prepassTestConstants = {};
    prepassTestConstants.hasAlbedoMap = _testObjects[0].submeshes[0].textures[tex_albedo] != NSNull.null;
    prepassTestConstants.hasNormalMap = _testObjects[0].submeshes[0].textures[tex_normal] != NSNull.null;
    prepassTestConstants.hasRoughnessMap = _testObjects[0].submeshes[0].textures[tex_roughness] != NSNull.null;
    prepassTestConstants.hasMetalicMap = _testObjects[0].submeshes[0].textures[tex_metalic] != NSNull.null;
    prepassTestConstants.hasOcclusionMap = _testObjects[0].submeshes[0].textures[tex_occlusion] != NSNull.null;
    prepassTestConstants.hasAnisotropicMap = _testObjects[0].submeshes[0].textures[tex_anisotropic] != NSNull.null;
    prepassTestConstants.flipVertically = NO;
    _renderPipelinePrepassTest = [_gBuffer renderPipelineStateWithConstants: prepassTestConstants
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
    
    // shadow
    _shadowManager = [[MGPShadowManager alloc] initWithDevice: self.device
                                                      library: self.defaultLibrary
                                             vertexDescriptor: _gBuffer.baseVertexDescriptor];
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
    camera_props[_currentBufferIndex].viewProjection = matrix_multiply(camera_props[_currentBufferIndex].projection, camera_props[_currentBufferIndex].view);
    camera_props[_currentBufferIndex].rotation = _cameraRotationInverseMatrix;
    camera_props[_currentBufferIndex].position = _cameraPos;
    
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
        p->model = matrix_multiply(matrix_from_translation(instance_pos[i].x, instance_pos[i].y, instance_pos[i].z), matrix_from_rotation(_animationTime, 0, 1, 0));
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
            light_dirs[i] = simd_normalize(vector4(rand() / (float)RAND_MAX - 0.5f, rand() / (float)RAND_MAX - 0.5f,
                                                   rand() / (float)RAND_MAX - 0.5f, 0.0f));
        }
    }
    
    for(NSInteger i = 0; i < _numLights; i++) {
        simd_float3 rot_dir = simd_cross(vector3(light_dirs[i].x, light_dirs[i].y, light_dirs[i].z), vector3(0.0f, 1.0f, 0.0f));
        simd_float4 dir = matrix_multiply(matrix_from_rotation(_animationTime * 3.0f, rot_dir.x, rot_dir.y, rot_dir.z), light_dirs[i]);
        simd_float3 eye = -simd_make_float3(dir);
        
        // set light properties
        MGPLight *light = _lights[i];
        light.color = light_colors[i];
        light.intensity = light_intensities[i];
        light.direction = simd_make_float3(dir);
        light.position = eye;
        light.castShadows = NO;
        
        // light properties -> buffer
        light_t *light_props_ptr = &light_props[_currentBufferIndex * kNumLight + i];
        *light_props_ptr = light.shaderLightProperties;
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
    
    // skybox pass
    _renderPassSkybox.colorAttachments[0].texture = self.view.currentDrawable.texture;
    _renderPassSkybox.depthAttachment.texture = _skyboxDepthTexture;
    id<MTLRenderCommandEncoder> skyboxPassEncoder = [commandBuffer renderCommandEncoderWithDescriptor: _renderPassSkybox];
    [self renderSkybox:skyboxPassEncoder];
    
    // G-buffer prepass
    id<MTLRenderCommandEncoder> prepassEncoder = [commandBuffer renderCommandEncoderWithDescriptor: _gBuffer.renderPassDescriptor];
    [self renderGBuffer:prepassEncoder];
    
    // G-buffer light-accumulation pass
    id<MTLRenderCommandEncoder> lightingPassEncoder = [commandBuffer renderCommandEncoderWithDescriptor: _gBuffer.lightingPassDescriptor];
    [self renderLighting:lightingPassEncoder];
    
    // G-buffer shade pass
    id<MTLRenderCommandEncoder> shadingPassEncoder = [commandBuffer renderCommandEncoderWithDescriptor: _gBuffer.shadingPassDescriptor];
    [self renderShading:shadingPassEncoder];
    
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
    NSArray<MGPMesh *> *meshes = _meshes;
    if(_showsTestObjects)
        meshes = _testObjects;
    
    for(MGPMesh *mesh in meshes) {
        for(MGPSubmesh *submesh in mesh.submeshes) {
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
    [self _initSkyboxDepthTexture];
}

@end
