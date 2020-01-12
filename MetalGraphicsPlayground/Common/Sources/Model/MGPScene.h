//
//  MGPScene.h
//  MetalPostProcessing
//
//  Created by 이현우 on 03/07/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "../../Shaders/SharedStructures.h"

NS_ASSUME_NONNULL_BEGIN

// TODO : GI, Meshes, Cameras, Lights...
@class MGPRenderer;
@class MGPSceneNode;
@class MGPImageBasedLighting;
@interface MGPScene : NSObject

// Global Illumination
@property (nonatomic) MGPImageBasedLighting * _Nullable IBL;

// Global light properties
@property (nonatomic) light_global_t lightGlobalProps;

// Root scene node
@property (nonatomic, readonly) MGPSceneNode *rootNode;

// Renderer
@property (nonatomic, weak) MGPRenderer *renderer;

@end

NS_ASSUME_NONNULL_END
