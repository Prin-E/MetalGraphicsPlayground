//
//  CommonMath.h
//  MetalGraphicsPlayground
//
//  Created by 이현우 on 09/05/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#ifndef CommonMath_h
#define CommonMath_h

inline float sqr(float f0) {
    return f0 * f0;
}

// ===============================================================================================
// http://holger.dammertz.org/stuff/notes_HammersleyOnHemisphere.html
// ===============================================================================================
inline float2 hammersley(uint i, uint N)
{
    // 2.3283064365386963e-10 = 0.5 / 0x10000000
    float ri = reverse_bits(i) * 2.3283064365386963e-10;
    return float2(float(i) / float(N), ri);
}

#endif /* CommonMath_h */
