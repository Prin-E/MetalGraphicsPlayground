//
//  Gizmo.metal
//  MetalTextureLOD
//
//  Created by 이현우 on 2019/08/20.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#include <metal_stdlib>
#include "SharedStructures.h"

using namespace metal;

typedef struct {
    float3 pos [[attribute(0)]];
} GizmoVertex;

typedef struct {
    float4 clipPos [[position]];
} GizmoFragment;

vertex GizmoFragment gizmo_wireframe_vert(GizmoVertex in [[stage_in]],
                                          constant camera_props_t &camera_props [[buffer(1)]],
                                          constant gizmo_props_t *gizmo_props [[buffer(2)]],
                                          uint iid [[instance_id]]) {
    GizmoFragment out;
    float4 pos = float4(in.pos * gizmo_props[iid].radius + gizmo_props[iid].position, 1.0);
    out.clipPos = camera_props.viewProjection * pos;
    return out;
}

fragment half4 gizmo_wireframe_frag(GizmoFragment in [[stage_in]]) {
    return half4(0, 0, 1, 1);
}
