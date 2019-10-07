//
//  MGPSceneNodeComponent.m
//  MetalGraphicsPlayground
//
//  Created by 이현우 on 2019/10/07.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import "MGPSceneNodeComponent.h"
#import "MGPSceneNode.h"

@implementation MGPSceneNodeComponent

- (simd_float4x4)localToWorldMatrix {
    return _node ? _node.localToWorldMatrix : matrix_identity_float4x4;
}

- (simd_float4x4)worldToLocalMatrix {
    return _node ? _node.worldToLocalMatrix : matrix_identity_float4x4;
}

- (simd_float4x4)localToWorldRotationMatrix {
    return _node ? _node.localToWorldRotationMatrix : matrix_identity_float4x4;
}

- (simd_float4x4)worldToLocalRotationMatrix {
    return _node ? _node.worldToLocalRotationMatrix : matrix_identity_float4x4;
}

- (simd_float3)position {
    return _node ? _node.position : simd_make_float3(0, 0, 0);
}

- (simd_float3)rotation {
    return _node ? _node.rotation : simd_make_float3(0, 0, 0);
}

- (simd_float3)scale {
    return _node ? _node.scale : simd_make_float3(1, 1, 1);
}

@end
