//
//  AppDelegate.m
//  MetalSceneGraph
//
//  Created by 이현우 on 2020/01/05.
//  Copyright © 2020 Prin_E. All rights reserved.
//

#import "AppDelegate.h"
#import "../Common/Sources/Model/MGPScene.h"
#import "../Common/Sources/Model/MGPSceneNode.h"
#import "../Common/Sources/Model/MGPPrimitiveNode.h"
#import "../Common/Sources/Model/MGPMeshComponent.h"
#import "../Common/Sources/Model/MGPLightComponent.h"
#import "../Common/Sources/Model/MGPCameraComponent.h"
#import "../Common/Sources/Model/MGPMesh.h"
#import "../Common/Sources/Model/MGPImageBasedLighting.h"
#import "../Common/Sources/Rendering/MGPDeferredRenderer.h"
#import "../Common/Sources/Rendering/MGPGBuffer.h"
#import "../Common/Sources/View/MGPView.h"

#define STB_IMAGE_IMPLEMENTATION
#import "../Common/STB/stb_image.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@property (weak) IBOutlet MGPView *view;
@property (strong) MGPDeferredRenderer *renderer;
@property (strong) NSTimer *timer;
@property (strong) MGPScene *scene;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    _renderer = [[MGPDeferredRenderer alloc] init];
    _view.renderer = _renderer;
    
    // scene
    _scene = [[MGPScene alloc] init];
    
    // TODO: IBL
    NSMutableArray *IBLs = [NSMutableArray array];
    NSArray<NSString*> *skyboxNames = @[/*@"Tropical_Beach_3k", @"Milkyway_small", @"WinterForest_Ref"*/];
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
        id<MTLTexture> skyboxIntermediateTexture = [_renderer.device newTextureWithDescriptor: skyboxTextureDescriptor];
        [skyboxIntermediateTexture replaceRegion:MTLRegionMake2D(0, 0, skyboxWidth, skyboxHeight)
                         mipmapLevel:0
                           withBytes:skyboxImageData
                         bytesPerRow:16*skyboxWidth];
        stbi_image_free(skyboxImageData);
        
        // Create GPU-only texture and blit pixels
        skyboxTextureDescriptor.usage = MTLTextureUsageShaderRead;
        skyboxTextureDescriptor.storageMode = MTLStorageModePrivate;
        id<MTLTexture> skyboxTexture = [_renderer.device newTextureWithDescriptor: skyboxTextureDescriptor];
        id<MTLCommandBuffer> blitBuffer = [_renderer.queue commandBuffer];
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
        
        MGPImageBasedLighting *IBL = [[MGPImageBasedLighting alloc] initWithDevice: _renderer.device
                                                                           library: _renderer.defaultLibrary
                                                                equirectangularMap: skyboxTexture];
        [IBLs addObject: IBL];
    }
    
    // Light globals
    light_global_t lightGlobal = _scene.lightGlobalProps;
    //lightGlobal.ambient_color = simd_make_float3(0.1, 0.096, 0.09);
    _scene.lightGlobalProps = lightGlobal;
    
    // Center
    MGPSceneNode *centerNode = [[MGPSceneNode alloc] init];
    centerNode.position = simd_make_float3(0, 0, -4);
    
    // Mesh
    material_t mat = {};
    MGPPrimitiveNode *meshNode = [[MGPPrimitiveNode alloc] initWithPrimitiveType:MGPPrimitiveNodeTypeSphere
                                                                vertexDescriptor:_renderer.gBuffer.baseVertexDescriptor
                                                                          device:_renderer.device];
    mat.roughness = 1.0;
    mat.metalic = 0.0;
    mat.albedo = simd_make_float3(1.0f, 0.0f, 0.0f);
    meshNode.material = mat;
    meshNode.scale = simd_make_float3(2, 2, 2);
    [centerNode addChild:meshNode];
    
    // mesh2
    MGPPrimitiveNode *mesh2Node = [[MGPPrimitiveNode alloc] initWithPrimitiveType:MGPPrimitiveNodeTypeSphere
                                                                 vertexDescriptor:_renderer.gBuffer.baseVertexDescriptor
                                                                           device:_renderer.device];
    mat.roughness = 1.0;
    mat.metalic = 0.0;
    mat.albedo = simd_make_float3(1.0f, 1.0f, 1.0f);
    mesh2Node.material = mat;
    mesh2Node.position = simd_make_float3(0, 4.0, 0);
    mesh2Node.scale = simd_make_float3(2,2,2);
    [centerNode addChild:mesh2Node];
    
    // mesh3
    MGPPrimitiveNode *mesh3Node = [[MGPPrimitiveNode alloc] initWithPrimitiveType:MGPPrimitiveNodeTypeCube
                                                                 vertexDescriptor:_renderer.gBuffer.baseVertexDescriptor
                                                                           device:_renderer.device];
    mat.roughness = 0.7;
    mat.metalic = 0.2;
    mat.albedo = simd_make_float3(0.2f, 1.0f, 0.2f);
    mesh3Node.material = mat;
    mesh3Node.position = simd_make_float3(1, 0, 0);
    mesh3Node.scale = simd_make_float3(0.5, 0.5, 0.5);
    [mesh2Node addChild:mesh3Node];
    
    srand((unsigned int)time(NULL));
    for(NSUInteger i = 0; i < 256*10; i++) {
        MGPPrimitiveNode *meshNode = [[MGPPrimitiveNode alloc] initWithPrimitiveType:MGPPrimitiveNodeTypeSphere
                                                                     vertexDescriptor:_renderer.gBuffer.baseVertexDescriptor
                                                                               device:_renderer.device];
        mat.roughness = 1.0;
        mat.metalic = 0.0;
        mat.albedo = simd_make_float3(1.0f, 1.0f, 1.0f);
        meshNode.material = mat;
        float r = rand()/(float)RAND_MAX;
        float r2 = rand()/(float)RAND_MAX;
        float r3 = rand()/(float)RAND_MAX;
        meshNode.position = simd_make_float3(cos(r*M_PI*2), sin(r*M_PI*2), 0) * (3.0+r2*3.0);
        meshNode.scale = simd_make_float3(1,1,1)*(r3+0.5)*0.1;
        [centerNode addChild:meshNode];
    }
    
    // Plane
    MGPPrimitiveNode *planeNode = [[MGPPrimitiveNode alloc] initWithPrimitiveType:MGPPrimitiveNodeTypePlane
                                                                 vertexDescriptor:_renderer.gBuffer.baseVertexDescriptor
                                                                           device:_renderer.device];
    planeNode.position = simd_make_float3(0, -6, 0);
    planeNode.scale = simd_make_float3(200, 100, 100);
    
    // Camera
    MGPSceneNode *cameraNode = [[MGPSceneNode alloc] init];
    MGPCameraComponent *cameraComp = [[MGPCameraComponent alloc] init];
    MGPProjectionState proj = cameraComp.projectionState;
    proj.nearPlane = 0.5;
    proj.farPlane = 100;
    cameraComp.projectionState = proj;
    [cameraNode addComponent:cameraComp];
    cameraNode.position = simd_make_float3(0, 0, -20);
    
    // Light
    MGPSceneNode *lightNode = [[MGPSceneNode alloc] init];
    MGPLightComponent *lightComp = [[MGPLightComponent alloc] init];
    lightComp.color = simd_make_float3(1.0f, 1.0f, 0.0f);
    lightComp.intensity = 4;
    lightComp.type = MGPLightTypeDirectional;
    lightComp.castShadows = YES;
    lightComp.shadowBias = 0.0005;
    lightComp.shadowNear = 0.5;
    lightComp.shadowFar = 30;
    [lightNode addComponent:lightComp];
    lightNode.position = simd_make_float3(12.0f, 12.0f, 0.0f);
    
    MGPLightComponent *pointLightComp = [[MGPLightComponent alloc] init];
    pointLightComp.color = simd_make_float3(1.0f, 0.4f, 0.0f);
    pointLightComp.intensity = 8;
    pointLightComp.radius = 100;
    pointLightComp.type = MGPLightTypePoint;
    pointLightComp.castShadows = NO;
    [meshNode addComponent:pointLightComp];
    
    [_scene.rootNode addChild: centerNode];
    [_scene.rootNode addChild: planeNode];
    [_scene.rootNode addChild: cameraNode];
    [_scene.rootNode addChild: lightNode];
    _renderer.scene = _scene;
    
    [cameraNode lookAt:meshNode.position];
    [lightNode lookAt:meshNode.position];

    if(IBLs.count > 0)
        self.scene.IBL = IBLs[0];
    
    __block NSTimeInterval prevTime = NSDate.timeIntervalSinceReferenceDate;
    __block NSInteger IBLIndex = 0;
    __block float IBLTime = 0;
    _timer = [NSTimer scheduledTimerWithTimeInterval:0.01666
                                             repeats:YES
                                               block:^(NSTimer * _Nonnull timer) {
        NSTimeInterval curTime = NSDate.timeIntervalSinceReferenceDate;
        float deltaTime = (curTime - prevTime);
        prevTime = curTime;
        
        static float rot = 0;
        rot += deltaTime*M_PI;
        static float y = 0;
        static bool flag = true;
        y += 0.1 * (flag ? 1 : -1);
        if(y > 16) {
            y = 16;
            flag = false;
        }
        else if(y < 0) {
            y = 0;
            flag = true;
        }
        
        IBLTime += deltaTime;
        if(IBLTime > 3.0f) {
            IBLTime -= 3.0f;
            if(IBLs.count > 0) {
                IBLIndex = (IBLIndex + 1) % IBLs.count;
                self.scene.IBL = IBLs[IBLIndex];
            }
        }
        
        centerNode.rotation = simd_make_float3(0, 0, rot);
        mesh2Node.rotation = simd_make_float3(0, rot, 0);
    }];
}

@end
