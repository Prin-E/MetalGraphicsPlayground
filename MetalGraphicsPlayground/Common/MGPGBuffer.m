//
//  MGPGBuffer.m
//  MetalDeferred
//
//  Created by 이현우 on 01/05/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import "MGPGBuffer.h"
#import "MGPView.h"
#import "MGPRenderer.h"

@implementation MGPGBuffer {
    id<MTLDevice> _device;
    CGSize _size;
    MTLRenderPassDescriptor *_renderPassDescriptor;
    MTLRenderPassDescriptor *_lightingPassDescriptor;
    MTLRenderPipelineDescriptor *_renderPipelineDescriptor;
}

#pragma mark - Initialization
- (instancetype)initWithDevice:(id<MTLDevice>)device size:(CGSize)newSize {
    self = [super init];
    if(self) {
        [self _initWithDevice:device
                         size:newSize];
    }
    return self;
}

- (void)_initWithDevice:(id<MTLDevice>)device size:(CGSize)newSize {
    _device = device;
    _size = newSize;
    [self _makeGBufferTextures];
    [self _makeRenderPipelineDescriptor];
    [self _makeRenderPassDescriptor];
    [self _makeLightingPassDescriptor];
}

- (void)_makeGBufferTextures {
    NSUInteger width = _size.width;
    NSUInteger height = _size.height;
    
    // albedo
    MTLTextureDescriptor *desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatBGRA8Unorm
                                                                                    width: width
                                                                                   height: height
                                                                                mipmapped: NO];
    desc.usage = MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget;
    desc.storageMode = MTLStorageModePrivate;
    _albedo = [_device newTextureWithDescriptor: desc];
    
    // normal
    desc.pixelFormat = MTLPixelFormatRGBA8Unorm;
    _depth = [_device newTextureWithDescriptor: desc];
    
    // pos
    desc.pixelFormat = MTLPixelFormatRGBA32Float;
    _pos = [_device newTextureWithDescriptor: desc];
    
    // depth
    desc.pixelFormat = MTLPixelFormatDepth32Float;
    _depth = [_device newTextureWithDescriptor: desc];
    
    // shading
    desc.pixelFormat = MTLPixelFormatRGBA8Unorm;
    _shading = [_device newTextureWithDescriptor: desc];
}

- (void)_makeRenderPipelineDescriptor {
    MTLRenderPipelineDescriptor *desc = [[MTLRenderPipelineDescriptor alloc] init];
    
    // color attachments
    desc.colorAttachments[0].pixelFormat = _albedo.pixelFormat;
    desc.colorAttachments[1].pixelFormat = _normal.pixelFormat;
    desc.colorAttachments[2].pixelFormat = _pos.pixelFormat;
    desc.colorAttachments[3].pixelFormat = _shading.pixelFormat;
    
    // depth attachment
    desc.depthAttachmentPixelFormat = _depth.pixelFormat;
    
    _renderPipelineDescriptor = desc;
}

- (void)_makeRenderPassDescriptor {
    if(_renderPassDescriptor == nil) {
        _renderPassDescriptor = [[MTLRenderPassDescriptor alloc] init];
        
        // color attachments
        _renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
        _renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
        _renderPassDescriptor.colorAttachments[1].loadAction = MTLLoadActionClear;
        _renderPassDescriptor.colorAttachments[1].storeAction = MTLStoreActionStore;
        _renderPassDescriptor.colorAttachments[2].loadAction = MTLLoadActionClear;
        _renderPassDescriptor.colorAttachments[2].storeAction = MTLStoreActionStore;
        _renderPassDescriptor.colorAttachments[3].loadAction = MTLLoadActionClear;
        _renderPassDescriptor.colorAttachments[3].storeAction = MTLStoreActionStore;
        _renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0);
        _renderPassDescriptor.colorAttachments[1].clearColor = MTLClearColorMake(0, 0, 0, 0);
        _renderPassDescriptor.colorAttachments[2].clearColor = MTLClearColorMake(0, 0, 0, 0);
        _renderPassDescriptor.colorAttachments[3].clearColor = MTLClearColorMake(0, 0, 0, 0);
        
        // depth attachments
        _renderPassDescriptor.depthAttachment.loadAction = MTLLoadActionClear;
        _renderPassDescriptor.depthAttachment.storeAction = MTLStoreActionStore;
    }
    
    // assign or replace textures
    _renderPassDescriptor.colorAttachments[0].texture = _albedo;
    _renderPassDescriptor.colorAttachments[1].texture = _normal;
    _renderPassDescriptor.colorAttachments[2].texture = _pos;
    _renderPassDescriptor.colorAttachments[3].texture = _shading;
    _renderPassDescriptor.depthAttachment.texture = _depth;
}

- (void)_makeLightingPassDescriptor {
    _lightingPassDescriptor = [[MTLRenderPassDescriptor alloc] init];
    
    // color attachments
    _renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    _renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
}

#pragma mark - Properties
- (MTLRenderPassDescriptor *)renderPassDescriptor {
    return _renderPassDescriptor;
}

- (MTLRenderPassDescriptor *)lightingPassDescriptor {
    return _lightingPassDescriptor;
}

- (MTLRenderPipelineDescriptor *)renderPipelineDescriptor {
    return _renderPipelineDescriptor;
}

- (CGSize)size {
    return _size;
}

#pragma mark - Resize
- (void)resize:(CGSize)newSize {
    NSUInteger width = newSize.width;
    NSUInteger height = newSize.height;
    if(_albedo.width != width || _albedo.height != height) {
        _size = newSize;
        [self _makeGBufferTextures];
        [self _makeRenderPassDescriptor];
    }
}

@end