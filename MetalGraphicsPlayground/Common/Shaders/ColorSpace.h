//
//  ColorSpace.h
//  MetalGraphicsPlayground
//
//  Created by 이현우 on 2019/08/16.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#ifndef ColorSpace_h
#define ColorSpace_h

template<typename T>
inline T linear_to_srgb(T linear) {
    T srgb = (linear <= 0.0031308) ? (linear * 12.92) : ((pow(linear, 1.0/2.4) * 1.055) - 0.055);
    return srgb;
}

template<typename T>
inline T srgb_to_linear(T srgb) {
    T linear = (srgb <= 0.04045) ? (srgb / 12.92) : pow((srgb + 0.055) / 1.055, 2.4);
    return linear;
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
