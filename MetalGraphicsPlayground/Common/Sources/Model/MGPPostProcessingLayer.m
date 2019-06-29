//
//  MGPPostProcessingLayer.m
//  MetalPostProcessing
//
//  Created by 이현우 on 24/06/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import "MGPPostProcessingLayer.h"

NSString * const MGPPostProcessingLayerErrorDomain = @"MGPPostProcessingLayerErrorDomain";

@implementation MGPPostProcessingLayer {
    id<MTLDevice> _device;
    id<MTLLibrary> _library;
}

- (instancetype)init {
    @throw [NSException exceptionWithName: MGPPostProcessingLayerErrorDomain
                                   reason: @"Use initWithDevice:library: instead."
                                 userInfo: @{
                                             NSLocalizedDescriptionKey : @"Use initWithDevice:library: instead."
                                             }];
    return nil;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device library:(id<MTLLibrary>)library {
    self = [super init];
    if(self) {
        _device = device;
        _library = library;
    }
    return self;
}

- (NSUInteger)renderingOrder {
    return MGPPostProcessingRenderingOrderAfterShadePass;
}

- (void)render:(id<MTLCommandBuffer>)buffer {
    // do nothing
}

@end

@implementation MGPPostProcessingLayerSSAO

- (instancetype)initWithDevice:(id<MTLDevice>)device library:(id<MTLLibrary>)library {
    self = [super initWithDevice: device library: library];
    if(self) {
        
    }
    return self;
}

- (NSUInteger)renderingOrder {
    return MGPPostProcessingRenderingOrderBeforeLightPass;
}

- (void)render: (id<MTLCommandBuffer>)buffer {
    
}

@end
