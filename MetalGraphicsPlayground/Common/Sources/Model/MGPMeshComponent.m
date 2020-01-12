//
//  MGPMeshComponent.m
//  MetalGraphicsPlayground
//
//  Created by 이현우 on 2019/10/07.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import "MGPMeshComponent.h"
#import "MGPMesh.h"

@implementation MGPMeshComponent

- (instancetype)init {
    self = [super init];
    if(self) {
        _material.albedo = simd_make_float3(1, 1, 1);
        _material.roughness = 0.5f;
        _material.metalic = 0.5f;
        _material.anisotropy = 0;
    }
    return self;
}

- (instancetype)initWithMesh:(MGPMesh*)mesh {
    self = [self init];
    if(self) {
        self.mesh = mesh;
    }
    return self;
}

- (instancetype)initWithMesh:(MGPMesh*)mesh
                    material:(material_t)material {
    self = [super init];
    if(self) {
        self.mesh = mesh;
        self.material = material;
    }
    return self;
}

- (instance_props_t)instanceProps {
    instance_props_t props;
    props.model = self.localToWorldMatrix;
    props.material = _material;
    return props;
}

@end
