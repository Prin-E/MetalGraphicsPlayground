//
//  AppDelegate.m
//  MGPSceneGraph
//
//  Created by 이현우 on 2020/01/05.
//  Copyright © 2020 Prin_E. All rights reserved.
//

#import "AppDelegate.h"
#import "../Common/Sources/Model/MGPScene.h"
#import "../Common/Sources/Model/MGPSceneNode.h"
#import "../Common/Sources/Model/MGPMeshComponent.h"
#import "../Common/Sources/Model/MGPLightComponent.h"
#import "../Common/Sources/Model/MGPCameraComponent.h"
#import "../Common/Sources/Model/MGPMesh.h"
#import "../Common/Sources/Rendering/MGPDeferredRenderer.h"
#import "../Common/Sources/Rendering/MGPGBuffer.h"
#import "../Common/Sources/View/MGPView.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@property (weak) IBOutlet MGPView *view;
@property (strong) MGPDeferredRenderer *renderer;
@property (strong) NSTimer *timer;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    _renderer = [[MGPDeferredRenderer alloc] init];
    _view.renderer = _renderer;
    
    MGPScene *scene = [[MGPScene alloc] init];
    light_global_t lightGlobal = scene.lightGlobalProps;
    lightGlobal.ambient_color = simd_make_float3(0.2, 0.2, 0.2);
    scene.lightGlobalProps = lightGlobal;
    
    // vertex descriptor
    MDLVertexDescriptor *mdlVertexDescriptor = MTKModelIOVertexDescriptorFromMetal(_renderer.gBuffer.baseVertexDescriptor);
    mdlVertexDescriptor.attributes[attrib_pos].name = MDLVertexAttributePosition;
    mdlVertexDescriptor.attributes[attrib_uv].name = MDLVertexAttributeTextureCoordinate;
    mdlVertexDescriptor.attributes[attrib_normal].name = MDLVertexAttributeNormal;
    mdlVertexDescriptor.attributes[attrib_tangent].name = MDLVertexAttributeTangent;
    
    // Center
    MGPSceneNode *centerNode = [[MGPSceneNode alloc] init];
    
    // Mesh
    MGPSceneNode *meshNode = [[MGPSceneNode alloc] init];
    MGPMeshComponent *meshComp = [[MGPMeshComponent alloc] init];
    MGPTextureLoader *textureLoader = [[MGPTextureLoader alloc] initWithDevice: _renderer.device];
    MDLMesh *mdlMesh = [MDLMesh newEllipsoidWithRadii: vector3(1.0f, 1.0f, 1.0f)
                                       radialSegments: 32
                                     verticalSegments: 32
                                         geometryType: MDLGeometryTypeTriangles
                                        inwardNormals: NO
                                           hemisphere: NO
                                            allocator: [[MTKMeshBufferAllocator alloc] initWithDevice: _renderer.device]];
     
    mdlMesh.vertexDescriptor = mdlVertexDescriptor;
    MGPMesh *mesh = [[MGPMesh alloc] initWithModelIOMesh: mdlMesh
                                 modelIOVertexDescriptor: mdlVertexDescriptor
                                           textureLoader: textureLoader
                                                  device: _renderer.device
                                        calculateNormals: NO
                                                   error: nil];
    meshComp.mesh = mesh;
    [meshNode addComponent: meshComp];
    meshNode.position = simd_make_float3(1.5, 0, 0);
    [centerNode addChild:meshNode];
    
    // Camera
    MGPSceneNode *cameraNode = [[MGPSceneNode alloc] init];
    MGPCameraComponent *cameraComp = [[MGPCameraComponent alloc] init];
    MGPProjectionState proj = cameraComp.projectionState;
    proj.nearPlane = 0.1;
    proj.farPlane = 100;
    cameraComp.projectionState = proj;
    [cameraNode addComponent:cameraComp];
    cameraNode.position = simd_make_float3(0, 0, -5);
    
    // Light
    /*
    MGPSceneNode *lightNode = [[MGPSceneNode alloc] init];
    MGPLightComponent *lightComp = [[MGPLightComponent alloc] init];
    lightComp.color = simd_make_float3(1.0f, 1.0f, 0.0f);
    lightComp.intensity = 1.0;
    lightComp.type = MGPLightTypeDirectional;
    */
    
    [scene.rootNode addChild: centerNode];
    [scene.rootNode addChild: cameraNode];
    _renderer.scene = scene;
    
    _timer = [NSTimer scheduledTimerWithTimeInterval:0.01
                                             repeats:YES
                                               block:^(NSTimer * _Nonnull timer) {
        static float rot = 0;
        rot += 0.01*M_PI;
        centerNode.rotation = simd_make_float3(0, 0, rot);
        //cameraNode.position = simd_make_float3(0, 0, z);
    }];
}

@end
