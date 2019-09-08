//
//  ColorSpace.h
//  MetalGraphicsPlayground
//
//  Created by 이현우 on 2019/08/16.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#ifndef ColorSpace_h
#define ColorSpace_h

#include <metal_stdlib>
using namespace metal;

template<typename T>
inline T linear_to_srgb(T linear) {
    T srgb_low = (linear * 12.92);
    T srgb_high = (pow(linear, 1.0/2.4) * 1.055) - 0.055;
    T a = step(0.0031308, linear);
    return mix(srgb_low, srgb_high, a);
}

template<typename T>
inline T srgb_to_linear(T srgb) {
    T linear_low = srgb / 12.92;
    T linear_high = pow((srgb + 0.055) / 1.055, 2.4);
    T a = step(0.04045, srgb);
    return mix(linear_low, linear_high, a);
}

template<typename T>
inline T linear_to_srgb_fast(T linear) {
    return pow(linear, 1.0/2.2);
}

template<typename T>
inline T srgb_to_linear_fast(T linear) {
    return pow(linear, 2.4);
}

#endif /* ColorSpace_h */
