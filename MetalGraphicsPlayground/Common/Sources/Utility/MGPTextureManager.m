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
        _unusedTemporaryTextures = [NSMutableDictionary new];
        _usedTemporaryTextures = [NSMutableDictionary new];
    }
    return self;
}

+ (MGPTextureManager *)sharedTextureManager {
    return _sharedTextureManager;
}

- (NSNumber*)_identifierFromWidth:(NSUInteger)width
                           height:(NSUInteger)height
                      pixelFormat:(MTLPixelFormat)pixelFormat
                      storageMode:(MTLStorageMode)storageMode
                            usage:(MTLTextureUsage)usage
                 mipmapLevelCount:(NSUInteger)mipmapLevelCount
                      arrayLength:(NSUInteger)arrayLength {
    NSUInteger identifier = width;
    identifier = (identifier << 14) | height;
    identifier = (identifier << 10) | pixelFormat;
    identifier = (identifier << 4) | storageMode;
    identifier = (identifier << 6) | usage;
    identifier = (identifier << 4) | mipmapLevelCount;
    identifier = (identifier << 4) | arrayLength;
    return @(identifier);
}

- (id<MTLTexture>)newTemporaryTextureWithDescriptor:(MTLTextureDescriptor *)descriptor {
    if(descriptor == nil)
        return nil;
    
    return [self newTemporaryTextureWithWidth:descriptor.width
                                       height:descriptor.height
                                  pixelFormat:descriptor.pixelFormat
                                  storageMode:descriptor.storageMode
                                        usage:descriptor.usage
                             mipmapLevelCount:descriptor.mipmapLevelCount
                                  arrayLength:descriptor.arrayLength];
}

- (id<MTLTexture>)newTemporaryTextureWithWidth:(NSUInteger)width
                                        height:(NSUInteger)height
                                   pixelFormat:(MTLPixelFormat)pixelFormat
                                   storageMode:(MTLStorageMode)storageMode
                                         usage:(MTLTextureUsage)usage
                              mipmapLevelCount:(NSUInteger)mipmapLevelCount
                                   arrayLength:(NSUInteger)arrayLength {
    NSNumber *identifier = [self _identifierFromWidth:width
                                               height:height
                                          pixelFormat:pixelFormat
                                          storageMode:storageMode
                                                usage:usage
                                     mipmapLevelCount:mipmapLevelCount
                                          arrayLength:arrayLength];
    
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
        descriptor.storageMode = storageMode;
        if(mipmapLevelCount > 1)
            descriptor.mipmapLevelCount = mipmapLevelCount;
        if(arrayLength > 1) {
            descriptor.textureType = MTLTextureType2DArray;
            descriptor.arrayLength = arrayLength;
        }
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
                                          storageMode:texture.storageMode
                                                usage:texture.usage
                                     mipmapLevelCount:texture.mipmapLevelCount
                                          arrayLength:texture.arrayLength];
    
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

- (void)clearUnusedTemporaryTextures {
    NSNumber *key = nil;
    NSEnumerator<NSNumber*> *e = _unusedTemporaryTextures.keyEnumerator;
    while((key = e.nextObject)) {
        [_unusedTemporaryTextures[key] removeAllObjects];
    }
    [_unusedTemporaryTextures removeAllObjects];
}

@end
