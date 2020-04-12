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
#import "../Common/Sources/Model/MGPScene.h"
#import "../Common/Sources/Model/MGPSceneNode.h"
#import "../Common/Sources/Model/MGPMeshComponent.h"
#import "../Common/Sources/Model/MGPLightComponent.h"
#import "../Common/Sources/Model/MGPCameraComponent.h"

#define STB_IMAGE_IMPLEMENTATION
#import "../Common/STB/stb_image.h"

#ifndef LERP
#define LERP(x,y,t) ((x)*(1.0-(t))+(y)*(t))
#endif

const size_t kNumInstance = 8;
const uint32_t MAX_NUM_LIGHTS = 128;
const float kLightIntensityBase = 0.25;
const float kLightIntensityVariation = 3.0;
const size_t DEFAULT_SHADOW_RESOLUTION = 512;
const float kCameraSpeed = 100;

#define DEG_TO_RAD(x) ((x)*0.0174532925)

@implementation DeferredRenderer {
    float _elapsedTime;
    bool _animate;
    float _animationTime;
    
    BOOL _moveFlags[6];     // Front, Back, Left, Right, Up, Down
    BOOL _moveFast;
    float _moveSpeeds[6];   // same as flags
    NSPoint _mouseDelta, _prevMousePos;
    
    BOOL _mouseDown;
    MGPCameraComponent *_camera;
    
    // image-based lighting
    NSArray<NSString*> *_skyboxNames;
    NSMutableDictionary<NSString*, MGPImageBasedLighting*> *_IBLs;
    NSInteger _currentIBLIndex;
    
    // Meshes
    NSArray<MGPMesh *> *_meshes;
    NSArray<MGPMesh *> *_testObjects;
    NSMutableArray<MGPSceneNode *> *_meshNodes;
    
    // Lights
    NSMutableArray<MGPLightComponent *> *_lights;
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
        _numLights = 1;
        _animate = YES;
        [self initAssets];
        [self initScene];
    }
    return self;
}

- (void)initAssets {
    // IBL
    _skyboxNames = @[@"bush_restaurant_1k", @"Tropical_Beach_3k", @"Factory_Catwalk_2k", @"Milkyway_small", @"WinterForest_Ref"];
    
    // vertex descriptor
    MDLVertexDescriptor *mdlVertexDescriptor = MTKModelIOVertexDescriptorFromMetal(self.gBuffer.baseVertexDescriptor);
    mdlVertexDescriptor.attributes[attrib_pos].name = MDLVertexAttributePosition;
    mdlVertexDescriptor.attributes[attrib_uv].name = MDLVertexAttributeTextureCoordinate;
    mdlVertexDescriptor.attributes[attrib_normal].name = MDLVertexAttributeNormal;
    mdlVertexDescriptor.attributes[attrib_tangent].name = MDLVertexAttributeTangent;
    
    // meshes
    _meshes = [MGPMesh loadMeshesFromURL: [[NSBundle mainBundle] URLForResource: @"firetruck"
                                                                  withExtension: @"obj"]
                 modelIOVertexDescriptor: mdlVertexDescriptor
                                  device: self.device
                        calculateNormals: YES
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
    
    /*
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
    
    mesh.submeshes[0].textures[tex_anisotropic] = [textureLoader newTextureFromURL: [[NSBundle mainBundle] URLForResource: @"AnisoDirection1" withExtension: @"jpg"]
                                                                           usage: MTLTextureUsageShaderRead
                                                                     storageMode: MTLStorageModePrivate
                                                                           error: nil];
     */
    
    _testObjects = @[ mesh ];
}

- (MGPImageBasedLighting *)loadIBLAtIndex:(NSUInteger)index {
    if(_IBLs == nil) {
        _IBLs = [NSMutableDictionary new];
    }
    
    NSString *skyboxName = _skyboxNames[index];
    MGPImageBasedLighting *IBL = [_IBLs objectForKey:skyboxName];
    if(IBL == nil) {
        NSString *skyboxImagePath = [[NSBundle mainBundle] pathForResource:skyboxName
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
        
        IBL = [[MGPImageBasedLighting alloc] initWithDevice: self.device
                                                    library: self.defaultLibrary
                                         equirectangularMap: skyboxTexture];
        
        _IBLs[skyboxName] = IBL;
    }
    return IBL;
}

- (void)initScene {
    if(self.scene == nil)
        self.scene = [[MGPScene alloc] init];
    
    // IBL
    self.scene.IBL = [self loadIBLAtIndex:_currentBufferIndex];
    
    // Mesh
    _meshNodes = [NSMutableArray new];
    for(NSUInteger i = 0; i < kNumInstance; i++) {
        MGPSceneNode *node = [[MGPSceneNode alloc] init];
        MGPMeshComponent *meshComp = [[MGPMeshComponent alloc] init];
        meshComp.mesh = !(_showsTestObjects) ? _meshes[0] : _testObjects[0];
        [node addComponent: meshComp];
        [_meshNodes addObject: node];
        [self.scene.rootNode addChild: node];
    }
    
    // Light
    _lights = [NSMutableArray new];
    for(NSUInteger i = 0; i < MAX_NUM_LIGHTS; i++) {
        MGPSceneNode *lightNode = [[MGPSceneNode alloc] init];
        MGPLightComponent *lightComp = [[MGPLightComponent alloc] init];
        [lightNode addComponent: lightComp];
        lightNode.enabled = i < _numLights;
        [_lights addObject: lightComp];
        [self.scene.rootNode addChild: lightNode];
    }
    
    // Camera
    MGPSceneNode *cameraNode = [[MGPSceneNode alloc] init];
    cameraNode.position = simd_make_float3(0.0f, 0.0f, -60.0f);
    MGPCameraComponent *cameraComp = [[MGPCameraComponent alloc] init];
    [cameraNode addComponent: cameraComp];
    [self.scene.rootNode addChild: cameraNode];
    _camera = cameraComp;
    
    // projection
    MGPProjectionState projection = _camera.projectionState;
    projection.aspectRatio = self.gBuffer.size.width / self.gBuffer.size.height;
    projection.fieldOfView = DEG_TO_RAD(60.0f);
    projection.nearPlane = 0.5f;
    projection.farPlane = 300.0f;
    projection.orthographicSize = 5;
    _camera.projectionState = projection;
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
        simd_float3 rot = _camera.rotation;
        rot.y = rot.y + pixelMouseDelta.x / (0.5f * self.gBuffer.size.height) * M_PI_2;
        rot.x = MIN(MAX(rot.x - pixelMouseDelta.y / (0.5f * self.gBuffer.size.height) * M_PI_2, -M_PI*0.4), M_PI*0.4);
        _camera.node.rotation = rot;
    }
    
    // move
    static int columnIndices[] = { 2, 2, 0, 0, 1, 1 };
    simd_float4x4 rotationMatrix = _camera.node.localToWorldRotationMatrix;
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
        _camera.node.position += positionAdd;
}

- (void)_updateUniformBuffers: (float)deltaTime {
    // IBLs
    self.scene.IBL =  [self loadIBLAtIndex:_currentIBLIndex];
    
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
    
    // Meshes
    for(NSInteger i = 0; i < kNumInstance; i++) {
        MGPSceneNode *meshNode = _meshNodes[i];
        meshNode.enabled = i < kNumInstance;
        
        if(meshNode.enabled) {
            meshNode.position = instance_pos[i];
            meshNode.rotation = simd_make_float3(0, _animationTime, 0);
            MGPMeshComponent *meshComp = (MGPMeshComponent *)[meshNode componentOfType:MGPMeshComponent.class];
            meshComp.mesh = !(_showsTestObjects) ? _meshes[0] : _testObjects[0];

            material_t material;
            material.albedo = instance_albedo[i];
            material.roughness = self.roughness;
            material.metalic = self.metalic;
            material.anisotropy = self.anisotropy;
            meshComp.material = material;
        }
    }
    
    // Lights
    static simd_float3 light_colors[MAX_NUM_LIGHTS];
    static float light_intensities[MAX_NUM_LIGHTS];
    static simd_float4 light_dirs[MAX_NUM_LIGHTS];
    static BOOL init_light_value = NO;
    if(!init_light_value) {
        init_light_value = YES;
        for(int i = 0; i < MAX_NUM_LIGHTS; i++) {
            light_colors[i] = vector3(rand() / (float)RAND_MAX, rand() / (float)RAND_MAX, rand() / (float)RAND_MAX);
            light_intensities[i] = kLightIntensityBase + rand() / (float)RAND_MAX * kLightIntensityVariation;
            light_dirs[i] = simd_normalize(vector4(rand() / (float)RAND_MAX - 0.5f, rand() / (float)RAND_MAX - 0.5f,
                                                   rand() / (float)RAND_MAX - 0.5f, 0.0f));
        }
    }
    
    for(NSInteger i = 0; i < MAX_NUM_LIGHTS; i++) {
        MGPLightComponent *light = _lights[i];
        if(i < _numLights) {
            light.node.enabled = YES;
            simd_float3 rot_dir = simd_cross(vector3(light_dirs[i].x, light_dirs[i].y, light_dirs[i].z), vector3(0.0f, 1.0f, 0.0f));
            simd_float4 dir = matrix_multiply(matrix_from_rotation(_animationTime * 3.0f, rot_dir.x, rot_dir.y, rot_dir.z), light_dirs[i]);
            simd_float3 eye = -simd_make_float3(dir);
            
            // set light properties
            light.color = light_colors[i];
            light.intensity = light_intensities[i];
            [light.node lookAt: light.position + simd_make_float3(dir)];
            light.node.position = eye;
            light.castShadows = NO;
        }
        else {
            light.node.enabled = NO;
        }
    }
    
    _elapsedTime += deltaTime;
    if(_animate)
        _animationTime += deltaTime;
}

@end
