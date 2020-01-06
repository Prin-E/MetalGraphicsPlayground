//
//  MGPMeshComponent.h
//  MetalGraphicsPlayground
//
//  Created by 이현우 on 2019/10/07.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import "MGPSceneNodeComponent.h"
#import "SharedStructures.h"

NS_ASSUME_NONNULL_BEGIN

@class MGPMesh;
@interface MGPMeshComponent : MGPSceneNodeComponent

@property (nonatomic, readwrite) MGPMesh *mesh;
@property (nonatomic, readwrite) material_t material;
@property (nonatomic, readonly) instance_props_t instanceProps;

@end

NS_ASSUME_NONNULL_END
