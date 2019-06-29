//
//  MGPShadowManager.h
//  MetalGraphicsPlayground
//
//  Created by 이현우 on 29/06/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import <Foundation/Foundation.h>
@import Metal;

NS_ASSUME_NONNULL_BEGIN

@class MGPShadowBuffer;
@class MGPLight;
@interface MGPShadowManager : NSObject

@property (nonatomic, readonly) id<MTLDevice> device;
@property (nonatomic, readonly) id<MTLLibrary> library;

- (instancetype)initWithDevice: (id<MTLDevice>)device
                       library: (id<MTLLibrary>)library;

- (MGPShadowBuffer *)newShadowBufferForLight: (MGPLight *)light
                                  resolution: (NSUInteger)resolution
                               cascadeLevels: (NSUInteger)cascadeLevels;

- (void)render: (id<MTLCommandBuffer>)buffer;

@end

NS_ASSUME_NONNULL_END
