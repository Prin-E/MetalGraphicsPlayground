//
//  MGPPostProcessing.m
//  MetalPostProcessing
//
//  Created by 이현우 on 24/06/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import "MGPPostProcessing.h"
#import "MGPPostProcessingLayer.h"
#import "../Utility/MGPTextureManager.h"

NSString * const MGPPostProcessingErrorDomain = @"MGPPostProcessingErrorDomain";

@implementation MGPPostProcessing {
    NSMutableArray<id<MGPPostProcessingLayer>> *_layers;
    NSMutableArray<id<MGPPostProcessingLayer>> *_layersForRendering;
    CGSize _size;
}

- (instancetype)init {
    @throw [NSException exceptionWithName: MGPPostProcessingErrorDomain
                                   reason: @"Use initWithDevice:library: instead."
                                 userInfo: @{
                                             NSLocalizedDescriptionKey : @"Use initWithDevice:library: instead."
                                             }];
    return nil;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
                       library:(id<MTLLibrary>)library {
    return [self initWithDevice:device
                        library:library
                 textureManager:[[MGPTextureManager alloc] initWithDevice:device]];
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
                       library:(id<MTLLibrary>)library
                textureManager:(MGPTextureManager *)textureManager {
    self = [super init];
    if(self) {
        _device = device;
        _library = library;
        _textureManager = textureManager;
        _layers = [NSMutableArray arrayWithCapacity: 8];
        _layersForRendering = [NSMutableArray arrayWithCapacity: 4];
    }
    return self;
}

- (void)addLayer:(id<MGPPostProcessingLayer>)layer {
    if(layer != nil) {
        BOOL insert = NO;
        
        for(NSInteger i = 0; i < _layers.count; i++) {
            if(_layers[i].renderingOrder > layer.renderingOrder) {
                [_layers insertObject: layer
                              atIndex: i];
                insert = YES;
                break;
            }
        }
        
        if(!insert) {
            [_layers addObject: layer];
        }
        
        layer.postProcessing = self;
        if(_size.width > 0 && _size.height > 0)
            [layer resize: _size];
    }
    else {
        NSLog(@"layer is null.");
    }
}

- (id<MGPPostProcessingLayer>)layerAtIndex:(NSUInteger)index {
    return _layers[index];
}

- (id<MGPPostProcessingLayer>)layerByClass:(Class)layerClass {
    for(id<MGPPostProcessingLayer> layer in _layers) {
        if(layer.class == layerClass)
            return layer;
    }
    return nil;
}

- (void)removeLayerAtIndex:(NSUInteger)index {
    id<MGPPostProcessingLayer> layer = [_layers objectAtIndex: index];
    layer.postProcessing = nil;
    [_layers removeObjectAtIndex:index];
}

- (void)removeLayerByClass:(Class)layerClass {
    for(NSUInteger i = 0; i < _layers.count; i++) {
        id<MGPPostProcessingLayer> layer = _layers[i];
        if(layer.class == layerClass) {
            [_layers removeObjectAtIndex:i];
            break;
        }
    }
}

- (id<MGPPostProcessingLayer>)objectAtIndexedSubscript: (NSUInteger)index {
    return [self layerAtIndex:index];
}

- (NSArray<id<MGPPostProcessingLayer>> *)orderedLayersForRenderingOrder:(MGPPostProcessingRenderingOrder)renderingOrder {
    NSMutableArray *list = [NSMutableArray arrayWithCapacity: 4];
    [self _fillOrderedLayers: list
           forRenderingOrder: renderingOrder];
    return list;
}

- (void)_fillOrderedLayers:(NSMutableArray *)list
         forRenderingOrder:(MGPPostProcessingRenderingOrder)renderingOrder {
    [list removeAllObjects];
    for(NSInteger i = 0; i < _layers.count; i++) {
        if(_layers[i].renderingOrder >= renderingOrder) {
            if(_layers[i].renderingOrder < renderingOrder + 1000 &&
               _layers[i].isEnabled) {
                [list addObject: _layers[i]];
            }
            else {
                break;
            }
        }
    }
}

- (void)render:(id<MTLCommandBuffer>)buffer forRenderingOrder:(MGPPostProcessingRenderingOrder)renderingOrder {
    [self _fillOrderedLayers: _layersForRendering
           forRenderingOrder: renderingOrder];
    for(id<MGPPostProcessingLayer> layer in _layersForRendering) {
        [layer render: buffer];
    }
}

- (void)resize:(CGSize)newSize {
    _size = newSize;
    for(id<MGPPostProcessingLayer> layer in _layers) {
        [layer resize: newSize];
    }
}

@end
