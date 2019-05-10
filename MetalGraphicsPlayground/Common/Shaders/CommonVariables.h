//
//  ShaderCommonVariables.h
//  MetalGraphicsPlayground
//
//  Created by 이현우 on 09/05/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#ifndef ShaderCommonVariables_h
#define ShaderCommonVariables_h

#include <metal_stdlib>
using namespace metal;

constant constexpr float PI = 3.14159265;
constant constexpr float PI_DIV = 1.0 / PI;
constant constexpr float PI_2 = PI * 2;
constant constexpr float PI_DIV2 = 1.0 / PI_2;

constexpr sampler linear(mip_filter::linear,
                         mag_filter::linear,
                         min_filter::linear,
                         coord::normalized,
                         address::repeat);
constexpr sampler nearest(mip_filter::nearest,
                          mag_filter::nearest,
                          min_filter::nearest,
                          coord::normalized,
                          address::repeat);

#endif /* ShaderCommonVariables_h */
