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
    MGPView *_view;
    MTLRenderPassDescriptor *_renderPassDescriptor;
}

#pragma mark - Initialization
- (instancetype)initWithView:(MGPView *)view {
    self = [super init];
    if(self) {
        [self _initWithView: view];
    }
    return self;
}

- (void)_initWithView: (MGPView *)view {
    _view = view;
    [self _makeGBufferTextures];
    [self _makeRenderPipeline];
    [self _makeRenderPassDescriptor];
}

- (void)_makeGBufferTextures {
    id<MTLTexture> drawableTexture = [_view currentDrawable].texture;
    NSUInteger width = drawableTexture.width;
    NSUInteger height = drawableTexture.height;
    
    id<MTLDevice> device = [_view.renderer device];
    
    // albedo
    MTLTextureDescriptor *desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatRGBA8Unorm
                                                                                    width: width
                                                                                   height: height
                                                                                mipmapped: NO];
    desc.usage = MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget;
    _albedo = [device newTextureWithDescriptor: desc];
    
    // normal
    desc.pixelFormat = MTLPixelFormatRGBA8Unorm;
    _depth = [device newTextureWithDescriptor: desc];
    
    // pos
    desc.pixelFormat = MTLPixelFormatRGBA32Float;
    _pos = [device newTextureWithDescriptor: desc];
    
    // depth
    desc.pixelFormat = MTLPixelFormatDepth32Float;
    _depth = [device newTextureWithDescriptor: desc];
    
    // shading
    desc.pixelFormat = MTLPixelFormatRGBA8Unorm;
    _shading = [device newTextureWithDescriptor: desc];
}

- (void)_makeRenderPipeline {
    id<MTLDevice> device = [_view.renderer device];
    
    MTLRenderPipelineDescriptor *desc = [[MTLRenderPipelineDescriptor alloc] init];
    
    // color attachments
    desc.colorAttachments[0].pixelFormat = _albedo.pixelFormat;
    desc.colorAttachments[1].pixelFormat = _normal.pixelFormat;
    desc.colorAttachments[2].pixelFormat = _pos.pixelFormat;
    desc.colorAttachments[3].pixelFormat = _shading.pixelFormat;
    
    // depth attachment
    desc.depthAttachmentPixelFormat = _depth.pixelFormat;
    
    NSError *error = nil;
    _gBufferPipeline = [device newRenderPipelineStateWithDescriptor: desc
                                                              error: &error];
    if(error) {
        @throw [NSException exceptionWithName:@"MGPGBufferException"
                                       reason:self.debugDescription
                                     userInfo:@{ @"NSError" : error }];
    }
}

- (void)_makeRenderPassDescriptor {
    if(_renderPassDescriptor == nil) {
        _renderPassDescriptor = [[MTLRenderPassDescriptor alloc] init];
        
        // color attachments
        _renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionDontCare;
        _renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
        _renderPassDescriptor.colorAttachments[1].loadAction = MTLLoadActionDontCare;
        _renderPassDescriptor.colorAttachments[1].storeAction = MTLStoreActionStore;
        _renderPassDescriptor.colorAttachments[2].loadAction = MTLLoadActionDontCare;
        _renderPassDescriptor.colorAttachments[2].storeAction = MTLStoreActionStore;
        _renderPassDescriptor.colorAttachments[3].loadAction = MTLLoadActionDontCare;
        _renderPassDescriptor.colorAttachments[3].storeAction = MTLStoreActionStore;
        
        // depth attachments
        _renderPassDescriptor.depthAttachment.loadAction = MTLLoadActionDontCare;
        _renderPassDescriptor.depthAttachment.storeAction = MTLStoreActionStore;
    }
    
    // assign or replace textures
    _renderPassDescriptor.colorAttachments[0].texture = _albedo;
    _renderPassDescriptor.colorAttachments[1].texture = _normal;
    _renderPassDescriptor.colorAttachments[2].texture = _pos;
    _renderPassDescriptor.colorAttachments[3].texture = _shading;
    _renderPassDescriptor.depthAttachment.texture = _depth;
}

#pragma mark - Properties
- (MTLRenderPassDescriptor *)renderPassDescriptor {
    return _renderPassDescriptor;
}

#pragma mark - Resize
- (void)resize {
    id<MTLTexture> drawableTexture = [_view currentDrawable].texture;
    NSUInteger width = drawableTexture.width;
    NSUInteger height = drawableTexture.height;
    if(_albedo.width != width || _albedo.height != height) {
        [self _makeGBufferTextures];
        [self _makeRenderPassDescriptor];
    }
}

@end
