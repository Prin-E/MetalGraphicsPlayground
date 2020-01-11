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
@property (strong) MGPScene *scene;

@end

@implementation AppDelegate

- (MGPMesh *)sharedMesh {
    static MGPMesh *mesh = nil;
    if(!mesh) {
        // vertex descriptor
        MDLVertexDescriptor *mdlVertexDescriptor = MTKModelIOVertexDescriptorFromMetal(_renderer.gBuffer.baseVertexDescriptor);
        mdlVertexDescriptor.attributes[attrib_pos].name = MDLVertexAttributePosition;
        mdlVertexDescriptor.attributes[attrib_uv].name = MDLVertexAttributeTextureCoordinate;
        mdlVertexDescriptor.attributes[attrib_normal].name = MDLVertexAttributeNormal;
        mdlVertexDescriptor.attributes[attrib_tangent].name = MDLVertexAttributeTangent;
        
        MGPTextureLoader *textureLoader = [[MGPTextureLoader alloc] initWithDevice: _renderer.device];
        MDLMesh *mdlMesh = [MDLMesh newEllipsoidWithRadii: vector3(0.5f, 0.5f, 0.5f)
                                           radialSegments: 32
                                         verticalSegments: 32
                                             geometryType: MDLGeometryTypeTriangles
                                            inwardNormals: NO
                                               hemisphere: NO
                                                allocator: [[MTKMeshBufferAllocator alloc] initWithDevice: _renderer.device]];
         
        mdlMesh.vertexDescriptor = mdlVertexDescriptor;
        mesh = [[MGPMesh alloc] initWithModelIOMesh: mdlMesh
                                     modelIOVertexDescriptor: mdlVertexDescriptor
                                               textureLoader: textureLoader
                                                      device: _renderer.device
                                            calculateNormals: NO
                                                       error: nil];
    }
    return mesh;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    _renderer = [[MGPDeferredRenderer alloc] init];
    _view.renderer = _renderer;
    
    // scene
    _scene = [[MGPScene alloc] init];
    
    // Light globals
    light_global_t lightGlobal = _scene.lightGlobalProps;
    lightGlobal.ambient_color = simd_make_float3(0.1, 0.096, 0.09);
    _scene.lightGlobalProps = lightGlobal;
    
    // Center
    MGPSceneNode *centerNode = [[MGPSceneNode alloc] init];
    
    // Mesh
    MGPMesh *mesh = self.sharedMesh;
    MGPSceneNode *meshNode = [[MGPSceneNode alloc] init];
    MGPMeshComponent *meshComp = [[MGPMeshComponent alloc] init];
    meshComp.mesh = mesh;
    material_t mat;
    mat.roughness = 1.0;
    mat.metalic = 0.0;
    mat.albedo = simd_make_float3(1.0f, 0.0f, 0.0f);
    meshComp.material = mat;
    [meshNode addComponent: meshComp];
    meshNode.position = simd_make_float3(0, 0, -4);
    [centerNode addChild:meshNode];
    
    // mesh2
    MGPSceneNode *mesh2Node = [[MGPSceneNode alloc] init];
    MGPMeshComponent *mesh2Comp = [[MGPMeshComponent alloc] init];
    mesh2Comp.mesh = mesh;
    mat.roughness = 1.0;
    mat.metalic = 0.0;
    mat.albedo = simd_make_float3(1.0f, 1.0f, 1.0f);
    mesh2Comp.material = mat;
    [mesh2Node addComponent:mesh2Comp];
    mesh2Node.position = simd_make_float3(0, 4.0, 0);
    mesh2Node.scale = simd_make_float3(2,2,2);
    [meshNode addChild:mesh2Node];
    
    // mesh3
    MGPSceneNode *mesh3Node = [[MGPSceneNode alloc] init];
    MGPMeshComponent *mesh3Comp = [[MGPMeshComponent alloc] init];
    mesh3Comp.mesh = mesh;
    mat.roughness = 0.7;
    mat.metalic = 0.2;
    mat.albedo = simd_make_float3(0.2f, 1.0f, 0.2f);
    mesh3Comp.material = mat;
    [mesh3Node addComponent:mesh3Comp];
    mesh3Node.position = simd_make_float3(1, 0, 0);
    mesh3Node.scale = simd_make_float3(0.5, 0.5, 0.5);
    [mesh2Node addChild:mesh3Node];
    
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
    lightComp.castShadows = NO;
    [lightNode addComponent:lightComp];
    lightNode.position = simd_make_float3(5.0f, 3.0f, 0.0f);
    
    MGPLightComponent *pointLightComp = [[MGPLightComponent alloc] init];
    pointLightComp.color = simd_make_float3(1.0f, 0.4f, 0.0f);
    pointLightComp.intensity = 8;
    pointLightComp.radius = 100;
    pointLightComp.type = MGPLightTypePoint;
    pointLightComp.castShadows = NO;
    [meshNode addComponent:pointLightComp];
    
    [_scene.rootNode addChild: centerNode];
    [_scene.rootNode addChild: cameraNode];
    [_scene.rootNode addChild: lightNode];
    _renderer.scene = _scene;
    
    [cameraNode lookAt:meshNode.position];
    [lightNode lookAt:meshNode.position];
    
    _timer = [NSTimer scheduledTimerWithTimeInterval:0.01666
                                             repeats:YES
                                               block:^(NSTimer * _Nonnull timer) {
        static float rot = 0;
        rot += 0.01666*M_PI;
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
        
        centerNode.rotation = simd_make_float3(0, 0, rot);
        mesh2Node.rotation = simd_make_float3(0, rot, 0);
    }];
}

@end
