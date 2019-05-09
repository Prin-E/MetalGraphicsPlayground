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
    id<MTLLibrary> _library;
    CGSize _size;
    MTLRenderPassDescriptor *_renderPassDescriptor;
    MTLRenderPassDescriptor *_lightingPassDescriptor;
    MTLRenderPipelineDescriptor *_renderPipelineDescriptor;
    MTLRenderPipelineDescriptor *_lightingPipelineDescriptor;
}

#pragma mark - Initialization
- (instancetype)initWithDevice:(id<MTLDevice>)device
                       library:(id<MTLLibrary>)library
                          size:(CGSize)newSize {
    self = [super init];
    if(self) {
        [self _initWithDevice:device
                      library:library
                         size:newSize];
    }
    return self;
}

- (void)_initWithDevice:(id<MTLDevice>)device
                library:(id<MTLLibrary>)library
                   size:(CGSize)newSize {
    _device = device;
    _library = library;
    _size = newSize;
    [self _makeGBufferTextures];
    [self _makeRenderPipelineDescriptor];
    [self _makeLightingPipelineDescriptor];
    [self _makeRenderPassDescriptor];
    [self _makeLightingPassDescriptor];
}

- (void)_makeGBufferTextures {
    NSUInteger width = MAX(64, _size.width);
    NSUInteger height = MAX(64, _size.height);
    
    // albedo
    MTLTextureDescriptor *desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatBGRA8Unorm
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
    
    desc.pixelFormat = MTLPixelFormatRGBA16Float;
    _lighting = [_device newTextureWithDescriptor: desc];
    _lighting.label = @"Lighting Output";
}

- (void)_makeRenderPipelineDescriptor {
    MTLRenderPipelineDescriptor *desc = [[MTLRenderPipelineDescriptor alloc] init];
    desc.label = @"G-buffer";
    
    // color attachments
    desc.colorAttachments[attachment_albedo].pixelFormat = _albedo.pixelFormat;
    desc.colorAttachments[attachment_normal].pixelFormat = _normal.pixelFormat;
    desc.colorAttachments[attachment_pos].pixelFormat = _pos.pixelFormat;
    desc.colorAttachments[attachment_shading].pixelFormat = _shading.pixelFormat;
    
    // depth attachment
    desc.depthAttachmentPixelFormat = _depth.pixelFormat;
    
    desc.vertexFunction = [_library newFunctionWithName:@"gbuffer_vert"];
    desc.fragmentFunction = [_library newFunctionWithName:@"gbuffer_frag"];
    
    _renderPipelineDescriptor = desc;
}

- (void)_makeLightingPipelineDescriptor {
    MTLRenderPipelineDescriptor *desc = [[MTLRenderPipelineDescriptor alloc] init];
    desc.label = @"Lighting";
    
    // color attachments
    desc.colorAttachments[0].pixelFormat = _lighting.pixelFormat;
    desc.vertexFunction = [_library newFunctionWithName:@"lighting_vert"];
    desc.fragmentFunction = [_library newFunctionWithName:@"lighting_frag"];
    
    _lightingPipelineDescriptor = desc;
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
    if(_lightingPassDescriptor == nil) {
        _lightingPassDescriptor = [[MTLRenderPassDescriptor alloc] init];
        
        // color attachments
        _lightingPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
        _lightingPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
        _lightingPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0);
    }
    
    _lightingPassDescriptor.colorAttachments[0].texture = _lighting;
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
        [self _makeLightingPassDescriptor];
    }
}

@end
