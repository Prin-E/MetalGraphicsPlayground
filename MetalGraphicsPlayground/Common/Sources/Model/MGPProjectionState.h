//
//  MGPProjectionState.h
//  MetalGraphicsPlayground
//
//  Created by 이현우 on 2019/08/23.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#ifndef MGPProjectionState_h
#define MGPProjectionState_h

typedef struct _MGPProjectionState {
    float aspectRatio;
    float orthographicRate;         // 0.0 : perspective, 1.0 : orthographic
    float orthographicSize;
    float fieldOfView;              // radian
    float nearPlane, farPlane;
} MGPProjectionState;


#endif /* MGPProjectionState_h */
