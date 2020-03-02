//
//  MGPTextureManager.h
//  MetalGraphicsPlayground
//
//  Created by 이현우 on 2020/03/03.
//  Copyright © 2020 Prin_E. All rights reserved.
//

#import <Foundation/Foundation.h>
@import Metal;

NS_ASSUME_NONNULL_BEGIN

@interface MGPTextureManager : NSObject

- (instancetype)initWithDevice:(id<MTLDevice>)device;

+ (MGPTextureManager *)sharedTextureManager;

- (id<MTLTexture>)newTemporaryTextureWithWidth:(NSUInteger)width
                                        height:(NSUInteger)height
                                   pixelFormat:(MTLPixelFormat)pixelFormat
                               resourceOptions:(MTLResourceOptions)options
                                         usage:(MTLTextureUsage)usage
                              mipmapLevelCount:(NSUInteger)mipmapLevelCount;
- (void)releaseTemporaryTexture:(id<MTLTexture>)texture;

@end

NS_ASSUME_NONNULL_END
