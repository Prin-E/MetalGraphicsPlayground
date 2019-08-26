//
//  MGPPlane.h
//  MetalGraphicsPlayground
//
//  Created by 이현우 on 2019/08/13.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <simd/simd.h>

NS_ASSUME_NONNULL_BEGIN

@interface MGPPlane : NSObject

- (instancetype)initWithCenter: (simd_float3)center
                        normal: (simd_float3)normal;

+ (instancetype)planeWithCenter: (simd_float3)center
                         normal: (simd_float3)normal;

@property simd_float3 center;
@property simd_float3 normal;

- (void)multiplyMatrix: (simd_float4x4)matrix;
- (simd_float4)equation; // <A,B,C,D> a.k.a. Ax+By+Cz+D=0
- (float)distanceToPosition: (simd_float3)position;

@end

NS_ASSUME_NONNULL_END
