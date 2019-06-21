//
//  MGPTextureLoader.m
//  MetalPostProcessing
//
//  Created by 이현우 on 11/06/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import "MGPTextureLoader.h"
#import "DDSTextureLoader.h"
@import MetalKit;

@implementation MGPTextureLoader {
    MTKTextureLoader *_mtkTextureLoader;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device {
    self = [super init];
    if(self) {
        _device = device;
    }
    return self;
}

- (id<MTLTexture>)newTextureFromPath:(NSString *)filePath
                               usage:(MTLTextureUsage)textureUsage
                         storageMode:(MTLStorageMode)storageMode
                               error:(NSError * _Nullable __autoreleasing *)error {
    if(filePath.length == 0) {
        *error = [NSError errorWithDomain: NSURLErrorDomain
                                     code: 0
                                 userInfo: nil];
        return nil;
    }
    NSURL *url = [NSURL URLWithString: [NSString stringWithFormat: @"file://%@", filePath]];
    return [self newTextureFromURL: url
                             usage: textureUsage
                       storageMode: storageMode
                             error: error];
}

- (id<MTLTexture>)newTextureFromURL:(NSURL *)url
                              usage:(MTLTextureUsage)textureUsage
                        storageMode:(MTLStorageMode)storageMode
                              error:(NSError * _Nullable __autoreleasing *)error {
    if(url.absoluteString.length == 0) {
        *error = [NSError errorWithDomain: NSURLErrorDomain
                                     code: 0
                                 userInfo: nil];
        return nil;
    }
    
    if([url isFileURL] && ![url checkResourceIsReachableAndReturnError: error]) {
        return nil;
    }
    
    NSString *absolutePath = [url absoluteString];
    
    if([absolutePath.pathExtension.lowercaseString isEqualToString: @"dds"]) {
        // Because MetalKit texture loader doesn't support DDS file loading,
        // We have to use custom implementation...
        return [self newDDSTextureFromURL: url
                                    usage: textureUsage
                              storageMode: storageMode
                                    error: error];
        
    }
    else {
        // Use default MetalKit texture loader
        NSMutableDictionary<MTKTextureLoaderOption, id> *options = [NSMutableDictionary dictionaryWithCapacity: 4];
        options[MTKTextureLoaderOptionTextureUsage] = @(textureUsage);
        options[MTKTextureLoaderOptionTextureStorageMode] = @(storageMode);
        return [_mtkTextureLoader newTextureWithContentsOfURL: url
                                                      options: options
                                                        error: error];
    }
}

- (id<MTLTexture>)newDDSTextureFromURL:(NSURL *)url
                                 usage:(MTLTextureUsage)textureUsage
                           storageMode:(MTLStorageMode)storageMode
                                 error:(NSError * _Nullable __autoreleasing *)error {
    
    NSString *filePath = url.absoluteString;
    filePath = [filePath stringByReplacingOccurrencesOfString: @"file://"
                                                   withString: @""];
    
    id<MTLTexture> texture = nil;
    DDS_ALPHA_MODE alphaMode = DDS_ALPHA_MODE_UNKNOWN;
    CreateDDSTextureFromFile(self.device,
                             filePath,
                             0,
                             textureUsage,
                             storageMode,
                             false,
                             &texture,
                             &alphaMode);
    return texture;
}

@end
