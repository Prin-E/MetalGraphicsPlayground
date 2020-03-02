//
//  MGPTextureManager.m
//  MetalGraphicsPlayground
//
//  Created by 이현우 on 2020/03/03.
//  Copyright © 2020 Prin_E. All rights reserved.
//

#import "MGPTextureManager.h"

static MGPTextureManager *_sharedTextureManager = nil;

@implementation MGPTextureManager {
    id<MTLDevice> _device;
    
    NSMutableDictionary<NSNumber*,NSMutableSet<id<MTLTexture>>*> *_unusedTemporaryTextures;
    NSMutableDictionary<NSNumber*,NSMutableSet<id<MTLTexture>>*> *_usedTemporaryTextures;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device {
    self = [super init];
    if(self) {
        _device = device;
        _sharedTextureManager = self;
    }
    return self;
}

+ (MGPTextureManager *)sharedTextureManager {
    return _sharedTextureManager;
}

- (NSNumber*)_identifierFromWidth:(NSUInteger)width
                           height:(NSUInteger)height
                      pixelFormat:(MTLPixelFormat)pixelFormat
                  resourceOptions:(MTLResourceOptions)options
                            usage:(MTLTextureUsage)usage
                 mipmapLevelCount:(NSUInteger)mipmapLevelCount {
    NSUInteger identifier = width;
    identifier = (identifier << 14) | height;
    identifier = (identifier << 10) | pixelFormat;
    identifier = (identifier << 6) | options;
    identifier = (identifier << 6) | usage;
    identifier = (identifier << 4) | mipmapLevelCount;
    return @(identifier);
}

- (id<MTLTexture>)newTemporaryTextureWithWidth:(NSUInteger)width
                                        height:(NSUInteger)height
                                   pixelFormat:(MTLPixelFormat)pixelFormat
                               resourceOptions:(MTLResourceOptions)options
                                         usage:(MTLTextureUsage)usage
                              mipmapLevelCount:(NSUInteger)mipmapLevelCount {
    NSNumber *identifier = [self _identifierFromWidth:width
                                               height:height
                                          pixelFormat:pixelFormat
                                      resourceOptions:options
                                                usage:usage
                                     mipmapLevelCount:mipmapLevelCount];
    
    NSMutableSet<id<MTLTexture>> *unusedSet = _unusedTemporaryTextures[identifier];
    NSMutableSet<id<MTLTexture>> *usedSet = _usedTemporaryTextures[identifier];
    if(!unusedSet) {
        unusedSet = [NSMutableSet set];
        _unusedTemporaryTextures[identifier] = unusedSet;
    }
    if(!usedSet) {
        usedSet = [NSMutableSet set];
        _usedTemporaryTextures[identifier] = usedSet;
    }
    
    id<MTLTexture> texture = nil;
    if([unusedSet count]) {
        texture = [unusedSet anyObject];
        [unusedSet removeObject:texture];
    }
    else {
        MTLTextureDescriptor *descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:pixelFormat
                                                                                              width:width
                                                                                             height:height
                                                                                          mipmapped:mipmapLevelCount > 1];
        descriptor.usage = usage;
        descriptor.resourceOptions = options;
        if(mipmapLevelCount > 1)
            descriptor.mipmapLevelCount = mipmapLevelCount;
        texture = [_device newTextureWithDescriptor:descriptor];
    }
    if(texture)
        [usedSet addObject:texture];
    return texture;
}

- (void)releaseTemporaryTexture:(id<MTLTexture>)texture {
    if(texture == nil)
        return;
    
    NSNumber *identifier = [self _identifierFromWidth:texture.width
                                               height:texture.height
                                          pixelFormat:texture.pixelFormat
                                      resourceOptions:texture.resourceOptions
                                                usage:texture.usage
                                     mipmapLevelCount:texture.mipmapLevelCount];
    
    NSMutableSet<id<MTLTexture>> *unusedSet = _unusedTemporaryTextures[identifier];
    NSMutableSet<id<MTLTexture>> *usedSet = _usedTemporaryTextures[identifier];
    if(!unusedSet) {
        unusedSet = [NSMutableSet set];
        _unusedTemporaryTextures[identifier] = unusedSet;
    }
    if(!usedSet) {
        usedSet = [NSMutableSet set];
        _usedTemporaryTextures[identifier] = usedSet;
    }
    
    if([usedSet containsObject:texture]) {
        [usedSet removeObject:texture];
        [unusedSet addObject:texture];
    }
    else {
        NSLog(@"This is not temporary texture(0x%016lX)!", (uintptr_t)texture);
    }
}

@end
