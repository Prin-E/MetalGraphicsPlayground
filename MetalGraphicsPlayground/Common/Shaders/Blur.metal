//
//  Blur.metal
//  MetalGraphicsPlayground
//
//  Created by 이현우 on 2019/09/09.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

// gaussain blur weights (pascal's triangle, from MiniEngine)
constant float weight_3x3[] = { 6.0 / 16.0, 4.0 / 16.0, 1.0 / 16.0 };
constant float weight_4x4[] = { 20.0 / 64.0, 15.0 / 64.0, 6.0 / 64.0, 1.0 / 64.0 };
constant float weight_5x5[] = { 70.0 / 256.0, 56.0 / 256.0, 28.0 / 256.0, 8.0 / 256.0, 1.0 / 256.0 };

float blur_gaussian_5x5() {
    // TODO
    return 0;
}
