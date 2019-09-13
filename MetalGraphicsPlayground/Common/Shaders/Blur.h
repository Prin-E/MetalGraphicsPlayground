//
//  Blur.h
//  MetalGraphicsPlayground
//
//  Created by 이현우 on 2019/09/14.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#ifndef Blur_h
#define Blur_h

// gaussain blur weights (pascal's triangle, from MiniEngine)
constant float blur_weight_3x3[] = { 6.0 / 16.0, 4.0 / 16.0, 1.0 / 16.0 };
constant float blur_weight_4x4[] = { 20.0 / 64.0, 15.0 / 64.0, 6.0 / 64.0, 1.0 / 64.0 };
constant float blur_weight_5x5[] = { 70.0 / 256.0, 56.0 / 256.0, 28.0 / 256.0, 8.0 / 256.0, 1.0 / 256.0 };

template<typename T>
T blur_gaussian(T a, T b, T c, T d, T e, T f, T g, T h, T i) {
    return  (a + i) * blur_weight_5x5[4] +
            (b + h) * blur_weight_5x5[3] +
            (c + g) * blur_weight_5x5[2] +
            (d + f) * blur_weight_5x5[1] +
            e       * blur_weight_5x5[0];
}

template<typename T>
T blur_gaussian(T a, T b, T c, T d, T e, T f, T g) {
    return  (a + g) * blur_weight_4x4[3] +
            (b + f) * blur_weight_4x4[2] +
            (c + e) * blur_weight_4x4[1] +
            d       * blur_weight_4x4[0];
}

template<typename T>
T blur_gaussian(T a, T b, T c, T d, T e) {
    return  (a + e) * blur_weight_3x3[2] +
            (b + d) * blur_weight_3x3[1] +
            c       * blur_weight_3x3[0];
}

#endif /* Blur_h */
