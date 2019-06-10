//
//  MGPGBuffer.m
//  MetalDeferred
//
//  Created by 이현우 on 01/05/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import "MGPGBuffer.h"
#import "MGPRenderer.h"
#import "../View/MGPView.h"
#import "../../Shaders/SharedStructures.h"

@implementation MGPGBuffer {
    id<MTLDevice> _device;
    id<MTLLibrary> _library;
    CGSize _size;
    MTLVertexDescriptor *_baseVertexDescriptor;
    MTLRenderPassDescriptor *_renderPassDescriptor;
    MTLRenderPassDescriptor *_lightingPassDescriptor;
    MTLRenderPipelineDescriptor *_renderPipelineDescriptor;
    MTLRenderPipelineDescriptor *_lightingPipelineDescriptor;
    
    NSMutableDictionary<MTLFunctionConstantValues *, id<MTLRenderPipelineState>> *_renderPipelineDict;
    id<MTLRenderPipelineState> _lightingPipelineState;
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
    _renderPipelineDict = [NSMutableDictionary dictionaryWithCapacity: 24];
    
    [self _makeGBufferTextures];
    [self _makeBaseVertexDescriptor];
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
    
    // tangent
    desc.pixelFormat = MTLPixelFormatRGBA16Float;
    _tangent = [_device newTextureWithDescriptor: desc];
    _tangent.label = @"Tangent G-buffer";
    
    // lighting
    desc.pixelFormat = MTLPixelFormatRGBA16Float;
    _lighting = [_device newTextureWithDescriptor: desc];
    _lighting.label = @"Lighting Output";
}

- (void)_makeBaseVertexDescriptor {
    _baseVertexDescriptor = [[MTLVertexDescriptor alloc] init];
    _baseVertexDescriptor.attributes[attrib_pos].format = MTLVertexFormatFloat3;
    _baseVertexDescriptor.attributes[attrib_pos].offset = 0;
    _baseVertexDescriptor.attributes[attrib_pos].bufferIndex = 0;
    _baseVertexDescriptor.attributes[attrib_uv].format = MTLVertexFormatFloat2;
    _baseVertexDescriptor.attributes[attrib_uv].offset = 12;
    _baseVertexDescriptor.attributes[attrib_uv].bufferIndex = 0;
    _baseVertexDescriptor.attributes[attrib_normal].format = MTLVertexFormatFloat3;
    _baseVertexDescriptor.attributes[attrib_normal].offset = 20;
    _baseVertexDescriptor.attributes[attrib_normal].bufferIndex = 0;
    _baseVertexDescriptor.attributes[attrib_tangent].format = MTLVertexFormatFloat3;
    _baseVertexDescriptor.attributes[attrib_tangent].offset = 32;
    _baseVertexDescriptor.attributes[attrib_tangent].bufferIndex = 0;
    _baseVertexDescriptor.attributes[attrib_bitangent].format = MTLVertexFormatFloat3;
    _baseVertexDescriptor.attributes[attrib_bitangent].offset = 44;
    _baseVertexDescriptor.attributes[attrib_bitangent].bufferIndex = 0;
    _baseVertexDescriptor.layouts[0].stride = 56;
    _baseVertexDescriptor.layouts[0].stepRate = 1;
    _baseVertexDescriptor.layouts[0].stepFunction = MTLStepFunctionPerVertex;
}

- (void)_makeRenderPipelineDescriptor {
    MTLRenderPipelineDescriptor *desc = [[MTLRenderPipelineDescriptor alloc] init];
    desc.label = @"G-buffer";
    
    // color attachments
    desc.colorAttachments[attachment_albedo].pixelFormat = _albedo.pixelFormat;
    desc.colorAttachments[attachment_normal].pixelFormat = _normal.pixelFormat;
    desc.colorAttachments[attachment_pos].pixelFormat = _pos.pixelFormat;
    desc.colorAttachments[attachment_shading].pixelFormat = _shading.pixelFormat;
    desc.colorAttachments[attachment_tangent].pixelFormat = _tangent.pixelFormat;
    
    // depth attachment
    desc.depthAttachmentPixelFormat = _depth.pixelFormat;
    
    // vertex descriptor
    desc.vertexDescriptor = _baseVertexDescriptor;
    
    // stages
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
        _renderPassDescriptor.colorAttachments[attachment_tangent].loadAction = MTLLoadActionClear;
        _renderPassDescriptor.colorAttachments[attachment_tangent].storeAction = MTLStoreActionStore;
        _renderPassDescriptor.colorAttachments[attachment_albedo].clearColor = MTLClearColorMake(0, 0, 0, 0);
        _renderPassDescriptor.colorAttachments[attachment_normal].clearColor = MTLClearColorMake(0, 0, 0, 0);
        _renderPassDescriptor.colorAttachments[attachment_pos].clearColor = MTLClearColorMake(0, 0, 0, 0);
        _renderPassDescriptor.colorAttachments[attachment_shading].clearColor = MTLClearColorMake(0, 0, 0, 0);
        _renderPassDescriptor.colorAttachments[attachment_tangent].clearColor = MTLClearColorMake(0, 0, 0, 0);
        
        // depth attachments
        _renderPassDescriptor.depthAttachment.loadAction = MTLLoadActionClear;
        _renderPassDescriptor.depthAttachment.storeAction = MTLStoreActionStore;
    }
    
    // assign or replace textures
    _renderPassDescriptor.colorAttachments[attachment_albedo].texture = _albedo;
    _renderPassDescriptor.colorAttachments[attachment_normal].texture = _normal;
    _renderPassDescriptor.colorAttachments[attachment_pos].texture = _pos;
    _renderPassDescriptor.colorAttachments[attachment_shading].texture = _shading;
    _renderPassDescriptor.colorAttachments[attachment_tangent].texture = _tangent;
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
- (MTLVertexDescriptor *)baseVertexDescriptor {
    return _baseVertexDescriptor;
}

- (MTLRenderPassDescriptor *)renderPassDescriptor {
    return _renderPassDescriptor;
}

- (MTLRenderPassDescriptor *)lightingPassDescriptor {
    return _lightingPassDescriptor;
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

#pragma mark - Render pipeline states
- (id<MTLRenderPipelineState>)renderPipelineStateWithConstants:(MTLFunctionConstantValues *)constantValues
                                                         error:(NSError **)error {
    if(error != nil) {
        *error = nil;
    }
    if(constantValues == nil) {
        constantValues = [[MTLFunctionConstantValues alloc] init];
    }
    
    id<MTLRenderPipelineState> renderPipelineState = [_renderPipelineDict objectForKey: constantValues];
    if(renderPipelineState == nil) {
        _renderPipelineDescriptor.vertexFunction = [_library newFunctionWithName: @"gbuffer_vert"
                                                                  constantValues: constantValues
                                                                           error: error];
        _renderPipelineDescriptor.fragmentFunction = [_library newFunctionWithName: @"gbuffer_frag"
                                                                    constantValues: constantValues
                                                                             error: error];
        renderPipelineState = [_device newRenderPipelineStateWithDescriptor: _renderPipelineDescriptor
                                                                      error: error];
    }
    return renderPipelineState;
}

- (id<MTLRenderPipelineState>)lightingPipelineStateWithError: (NSError **)error {
    if(error != nil) {
        *error = nil;
    }
    if(_lightingPipelineState == nil) {
        _lightingPipelineState = [_device newRenderPipelineStateWithDescriptor: _lightingPipelineDescriptor
                                                                         error: error];
    }
    return _lightingPipelineState;
}

@end
