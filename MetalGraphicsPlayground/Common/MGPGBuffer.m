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
#import "Shaders/SharedStructures.h"

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
    MTLTextureDescriptor *desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatRGBA16Float
                                                                                    width: width
                                                                                   height: height
                                                                                mipmapped: NO];
    desc.usage = MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget;
    desc.storageMode = MTLStorageModePrivate;
    _albedo = [_device newTextureWithDescriptor: desc];
    _albedo.label = @"Albedo G-buffer";
    
    // normal
    desc.pixelFormat = MTLPixelFormatRGBA16Float;
    _normal = [_device newTextureWithDescriptor: desc];
    _normal.label = @"Normal G-buffer";
    
    // pos
    desc.pixelFormat = MTLPixelFormatRGBA32Float;
    _pos = [_device newTextureWithDescriptor: desc];
    _pos.label = @"Position G-buffer";
    
    // depth
    desc.pixelFormat = MTLPixelFormatDepth32Float_Stencil8;
    _depth = [_device newTextureWithDescriptor: desc];
    _depth.label = @"Depth G-buffer";
    
    // shading
    desc.pixelFormat = MTLPixelFormatBGRA8Unorm;
    _shading = [_device newTextureWithDescriptor: desc];
    _shading.label = @"Shading G-buffer";
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
        _renderPassDescriptor.colorAttachments[attachment_albedo].loadAction = MTLLoadActionClear;
        _renderPassDescriptor.colorAttachments[attachment_albedo].storeAction = MTLStoreActionStore;
        _renderPassDescriptor.colorAttachments[attachment_normal].loadAction = MTLLoadActionClear;
        _renderPassDescriptor.colorAttachments[attachment_normal].storeAction = MTLStoreActionStore;
        _renderPassDescriptor.colorAttachments[attachment_pos].loadAction = MTLLoadActionClear;
        _renderPassDescriptor.colorAttachments[attachment_pos].storeAction = MTLStoreActionStore;
        _renderPassDescriptor.colorAttachments[attachment_shading].loadAction = MTLLoadActionClear;
        _renderPassDescriptor.colorAttachments[attachment_shading].storeAction = MTLStoreActionStore;
        _renderPassDescriptor.colorAttachments[attachment_albedo].clearColor = MTLClearColorMake(0, 0, 0, 0);
        _renderPassDescriptor.colorAttachments[attachment_normal].clearColor = MTLClearColorMake(0, 0, 0, 0);
        _renderPassDescriptor.colorAttachments[attachment_pos].clearColor = MTLClearColorMake(0, 0, 0, 0);
        _renderPassDescriptor.colorAttachments[attachment_shading].clearColor = MTLClearColorMake(0, 0, 0, 0);
        
        // depth attachments
        _renderPassDescriptor.depthAttachment.loadAction = MTLLoadActionClear;
        _renderPassDescriptor.depthAttachment.storeAction = MTLStoreActionStore;
    }
    
    // assign or replace textures
    _renderPassDescriptor.colorAttachments[attachment_albedo].texture = _albedo;
    _renderPassDescriptor.colorAttachments[attachment_normal].texture = _normal;
    _renderPassDescriptor.colorAttachments[attachment_pos].texture = _pos;
    _renderPassDescriptor.colorAttachments[attachment_shading].texture = _shading;
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
