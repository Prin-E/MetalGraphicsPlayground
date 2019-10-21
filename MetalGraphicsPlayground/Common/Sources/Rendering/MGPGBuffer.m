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
    MGPGBufferAttachmentType _attachments;
    MTLVertexDescriptor *_baseVertexDescriptor;
    MTLRenderPassDescriptor *_renderPassDescriptor;
    MTLRenderPassDescriptor *_lightingPassBaseDescriptor;
    MTLRenderPassDescriptor *_lightingPassAddDescriptor;
    MTLRenderPassDescriptor *_shadingPassDescriptor;
    MTLRenderPipelineDescriptor *_renderPipelineDescriptor;
    MTLRenderPipelineDescriptor *_lightingPipelineDescriptor;
    MTLRenderPipelineDescriptor *_shadingPipelineDescriptor;
    
    // key : bit-flag of function constant values
    // value : render-pipeline state
    NSMutableDictionary<NSNumber *, id<MTLRenderPipelineState>> *_renderPipelineDict;
    id<MTLRenderPipelineState> _lightingPipelineState;
    NSMutableDictionary<NSNumber *, id<MTLRenderPipelineState>> *_shadingPipelineDict;
    NSMutableDictionary<NSNumber *, id<MTLRenderPipelineState>> *_nonLightCulledShadingPipelineDict;
}

#pragma mark - Initialization
- (instancetype)initWithDevice:(id<MTLDevice>)device
                       library:(id<MTLLibrary>)library
                          size:(CGSize)newSize {
    self = [super init];
    if(self) {
        [self _initWithDevice:device
                      library:library
                         size:newSize
                  attachments:MGPGBufferAttachmentTypeAll];
    }
    return self;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
                       library:(id<MTLLibrary>)library
                          size:(CGSize)newSize
                   attachments:(MGPGBufferAttachmentType)attachments {
    self = [super init];
    if(self) {
        [self _initWithDevice:device
                      library:library
                         size:newSize
                  attachments:attachments];
    }
    return self;
}

- (void)_initWithDevice:(id<MTLDevice>)device
                library:(id<MTLLibrary>)library
                   size:(CGSize)newSize
            attachments:(MGPGBufferAttachmentType)attachments {
    _device = device;
    _library = library;
    _size = newSize;
    _renderPipelineDict = [NSMutableDictionary dictionaryWithCapacity: 24];
    _shadingPipelineDict = [NSMutableDictionary dictionaryWithCapacity: 4];
    
    [self _makeGBufferTextures];
    [self _makeBaseVertexDescriptor];
    [self _makeRenderPipelineDescriptor];
    [self _makeLightingPipelineDescriptor];
    [self _makeShadingPipelineDescriptor];
    [self _makeRenderPassDescriptor];
    [self _makeLightingPassDescriptor];
    [self _makeShadingPassDescriptor];
}

- (void)_makeGBufferTextures {
    NSUInteger width = MAX(64, _size.width);
    NSUInteger height = MAX(64, _size.height);
    
    // albedo
    MTLTextureDescriptor *desc = [MTLTextureDescriptor new];
    desc.textureType = MTLTextureType2D;
    desc.width = width;
    desc.height = height;
    desc.usage = MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget;
    desc.storageMode = MTLStorageModePrivate;
    
    if(_attachments | MGPGBufferAttachmentTypeAlbedo) {
        desc.pixelFormat = MTLPixelFormatBGRA8Unorm;
        _albedo = [_device newTextureWithDescriptor: desc];
        _albedo.label = @"Albedo G-buffer";
    }
    else {
        _albedo = nil;
    }
    
    // normal
    if(_attachments | MGPGBufferAttachmentTypeNormal) {
        desc.pixelFormat = MTLPixelFormatRGB10A2Unorm;
        _normal = [_device newTextureWithDescriptor: desc];
        _normal.label = @"Normal G-buffer";
    }
    else {
        _normal = nil;
    }
    
    // depth
    if(_attachments | MGPGBufferAttachmentTypeDepth) {
        desc.pixelFormat = MTLPixelFormatDepth32Float_Stencil8;
        _depth = [_device newTextureWithDescriptor: desc];
        _depth.label = @"Depth G-buffer";
    }
    else {
        _depth = nil;
    }
    
    // shading
    if(_attachments | MGPGBufferAttachmentTypeShading) {
        desc.pixelFormat = MTLPixelFormatBGRA8Unorm;
        _shading = [_device newTextureWithDescriptor: desc];
        _shading.label = @"Shading G-buffer";
    }
    else {
        _shading = nil;
    }
    
    // tangent
    if(_attachments | MGPGBufferAttachmentTypeTangent) {
        desc.pixelFormat = MTLPixelFormatRGB10A2Unorm;
        _tangent = [_device newTextureWithDescriptor: desc];
        _tangent.label = @"Tangent G-buffer";
    }
    else {
        _tangent = nil;
    }
    
    // lighting
    if(_attachments | MGPGBufferAttachmentTypeLighting) {
        desc.pixelFormat = MTLPixelFormatRGBA16Float;
        _lighting = [_device newTextureWithDescriptor: desc];
        _lighting.label = @"Light Accumulation G-buffer";
    }
    else {
        _lighting = nil;
    }
    
    // shade-output
    if(_attachments | MGPGBufferAttachmentTypeOutput) {
        desc.pixelFormat = MTLPixelFormatRGBA16Float;
        _output = [_device newTextureWithDescriptor: desc];
        _output.label = @"Output G-buffer";
    }
    else {
        _output = nil;
    }
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
    _baseVertexDescriptor.layouts[0].stride = 44;
    _baseVertexDescriptor.layouts[0].stepRate = 1;
    _baseVertexDescriptor.layouts[0].stepFunction = MTLStepFunctionPerVertex;
}

- (void)_makeRenderPipelineDescriptor {
    MTLRenderPipelineDescriptor *desc = [[MTLRenderPipelineDescriptor alloc] init];
    desc.label = @"G-buffer";
    
    // color attachments
    desc.colorAttachments[attachment_albedo].pixelFormat = _albedo.pixelFormat;
    desc.colorAttachments[attachment_normal].pixelFormat = _normal.pixelFormat;
    desc.colorAttachments[attachment_shading].pixelFormat = _shading.pixelFormat;
    desc.colorAttachments[attachment_tangent].pixelFormat = _tangent.pixelFormat;
    
    // depth attachment
    desc.depthAttachmentPixelFormat = _depth.pixelFormat;
    
    // vertex descriptor
    desc.vertexDescriptor = _baseVertexDescriptor;
    
    _renderPipelineDescriptor = desc;
}

- (void)_makeLightingPipelineDescriptor {
    MTLRenderPipelineDescriptor *desc = [[MTLRenderPipelineDescriptor alloc] init];
    desc.label = @"Lighting";
    
    // color attachments
    desc.colorAttachments[0].pixelFormat = _lighting.pixelFormat;
    desc.colorAttachments[0].blendingEnabled = YES;
    desc.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
    desc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorOne;
    desc.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOne;
    desc.vertexFunction = [_library newFunctionWithName:@"screen_vert"];
    desc.fragmentFunction = [_library newFunctionWithName:@"gbuffer_light_frag"];
    _lightingPipelineDescriptor = desc;
}

- (void)_makeShadingPipelineDescriptor {
    MTLRenderPipelineDescriptor *desc = [[MTLRenderPipelineDescriptor alloc] init];
    desc.label = @"Shading";
    desc.colorAttachments[0].pixelFormat = _output.pixelFormat;
    _shadingPipelineDescriptor = desc;
}

- (void)_makeRenderPassDescriptor {
    if(_renderPassDescriptor == nil) {
        _renderPassDescriptor = [[MTLRenderPassDescriptor alloc] init];
        
        // color attachments
        _renderPassDescriptor.colorAttachments[attachment_albedo].loadAction = MTLLoadActionClear;
        _renderPassDescriptor.colorAttachments[attachment_albedo].storeAction = MTLStoreActionStore;
        _renderPassDescriptor.colorAttachments[attachment_normal].loadAction = MTLLoadActionClear;
        _renderPassDescriptor.colorAttachments[attachment_normal].storeAction = MTLStoreActionStore;
        _renderPassDescriptor.colorAttachments[attachment_shading].loadAction = MTLLoadActionClear;
        _renderPassDescriptor.colorAttachments[attachment_shading].storeAction = MTLStoreActionStore;
        _renderPassDescriptor.colorAttachments[attachment_tangent].loadAction = MTLLoadActionClear;
        _renderPassDescriptor.colorAttachments[attachment_tangent].storeAction = MTLStoreActionStore;
        _renderPassDescriptor.colorAttachments[attachment_albedo].clearColor = MTLClearColorMake(0, 0, 0, 0);
        _renderPassDescriptor.colorAttachments[attachment_normal].clearColor = MTLClearColorMake(0, 0, 0, 0);
        _renderPassDescriptor.colorAttachments[attachment_shading].clearColor = MTLClearColorMake(0, 0, 0, 0);
        _renderPassDescriptor.colorAttachments[attachment_tangent].clearColor = MTLClearColorMake(0, 0, 0, 0);
        
        // depth attachments
        _renderPassDescriptor.depthAttachment.loadAction = MTLLoadActionClear;
        _renderPassDescriptor.depthAttachment.storeAction = MTLStoreActionStore;
    }
    
    // assign or replace textures
    _renderPassDescriptor.colorAttachments[attachment_albedo].texture = _albedo;
    _renderPassDescriptor.colorAttachments[attachment_normal].texture = _normal;
    _renderPassDescriptor.colorAttachments[attachment_shading].texture = _shading;
    _renderPassDescriptor.colorAttachments[attachment_tangent].texture = _tangent;
    _renderPassDescriptor.depthAttachment.texture = _depth;
}

- (void)_makeLightingPassDescriptor {
    if(_lightingPassBaseDescriptor == nil) {
        _lightingPassBaseDescriptor = [[MTLRenderPassDescriptor alloc] init];
        
        // color attachments
        _lightingPassBaseDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
        _lightingPassBaseDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    }
    if(_lightingPassAddDescriptor == nil) {
        _lightingPassAddDescriptor = [[MTLRenderPassDescriptor alloc] init];
        
        // color attachments
        _lightingPassAddDescriptor.colorAttachments[0].loadAction = MTLLoadActionLoad;
        _lightingPassAddDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    }
    
    _lightingPassBaseDescriptor.colorAttachments[0].texture = _lighting;
    _lightingPassAddDescriptor.colorAttachments[0].texture = _lighting;
}

- (void)_makeShadingPassDescriptor {
    if(_shadingPassDescriptor == nil) {
        _shadingPassDescriptor = [[MTLRenderPassDescriptor alloc] init];
        
        // color attachments
        _shadingPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
        _shadingPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
        _shadingPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0);
    }
    
    _shadingPassDescriptor.colorAttachments[0].texture = _output;
}

#pragma mark - Properties
- (MTLVertexDescriptor *)baseVertexDescriptor {
    return _baseVertexDescriptor;
}

- (MTLRenderPassDescriptor *)renderPassDescriptor {
    return _renderPassDescriptor;
}

- (MTLRenderPassDescriptor *)lightingPassBaseDescriptor {
    return _lightingPassBaseDescriptor;
}

- (MTLRenderPassDescriptor *)lightingPassAddDescriptor {
    return _lightingPassAddDescriptor;
}

- (MTLRenderPassDescriptor *)shadingPassDescriptor {
    return _shadingPassDescriptor;
}

- (CGSize)size {
    return _size;
}

- (void)setAttachments:(MGPGBufferAttachmentType)attachments {
    _attachments = attachments;
    [self _makeGBufferTextures];
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
        [self _makeShadingPassDescriptor];
    }
}

#pragma mark - Render pipeline states
- (id<MTLRenderPipelineState>)renderPipelineStateWithConstants:(MGPGBufferPrepassFunctionConstants)constants
                                                         error:(NSError **)error {
    if(error != nil) {
        *error = nil;
    }
    
    NSUInteger bitflag = 0;
    bitflag |= constants.hasAlbedoMap ? (1L << fcv_albedo) : 0;
    bitflag |= constants.hasNormalMap ? (1L << fcv_normal) : 0;
    bitflag |= constants.hasRoughnessMap ? (1L << fcv_roughness) : 0;
    bitflag |= constants.hasMetalicMap ? (1L << fcv_metalic) : 0;
    bitflag |= constants.hasOcclusionMap ? (1L << fcv_occlusion) : 0;
    bitflag |= constants.hasAnisotropicMap ? (1L << fcv_anisotropic) : 0;
    bitflag |= constants.flipVertically ? (1L << fcv_flip_vertically) : 0;
    bitflag |= constants.sRGBTexture ? (1L << fcv_srgb_texture) : 0;
    
    NSNumber *key = @(bitflag);
    id<MTLRenderPipelineState> renderPipelineState = [_renderPipelineDict objectForKey: key];
    if(renderPipelineState == nil) {
        // make function constant values object
        MTLFunctionConstantValues *constantValues = [MTLFunctionConstantValues new];
        [constantValues setConstantValue: &constants.hasAlbedoMap
                                    type: MTLDataTypeBool
                                 atIndex: fcv_albedo];
        [constantValues setConstantValue: &constants.hasNormalMap
                                    type: MTLDataTypeBool
                                 atIndex: fcv_normal];
        [constantValues setConstantValue: &constants.hasRoughnessMap
                                    type: MTLDataTypeBool
                                 atIndex: fcv_roughness];
        [constantValues setConstantValue: &constants.hasMetalicMap
                                    type: MTLDataTypeBool
                                 atIndex: fcv_metalic];
        [constantValues setConstantValue: &constants.hasOcclusionMap
                                    type: MTLDataTypeBool
                                 atIndex: fcv_occlusion];
        [constantValues setConstantValue: &constants.hasAnisotropicMap
                                    type: MTLDataTypeBool
                                 atIndex: fcv_anisotropic];
        [constantValues setConstantValue: &constants.flipVertically
                                    type: MTLDataTypeBool
                                 atIndex: fcv_flip_vertically];
        [constantValues setConstantValue: &constants.sRGBTexture
                                    type: MTLDataTypeBool
                                 atIndex: fcv_srgb_texture];
        
        _renderPipelineDescriptor.vertexFunction = [_library newFunctionWithName: @"gbuffer_prepass_vert"
                                                                  constantValues: constantValues
                                                                           error: error];
        _renderPipelineDescriptor.fragmentFunction = [_library newFunctionWithName: @"gbuffer_prepass_frag"
                                                                    constantValues: constantValues
                                                                             error: error];
        renderPipelineState = [_device newRenderPipelineStateWithDescriptor: _renderPipelineDescriptor
                                                                      error: error];
        _renderPipelineDict[key] = renderPipelineState;
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

- (id<MTLRenderPipelineState>)shadingPipelineStateWithConstants: (MGPGBufferShadingFunctionConstants)constants
                                                          error: (NSError **)error; {
    if(error != nil) {
        *error = nil;
    }
    
    NSUInteger bitflag = 0;
    bitflag |= constants.hasIBLIrradianceMap ? (1L << fcv_uses_ibl_irradiance_map) : 0;
    bitflag |= constants.hasIBLSpecularMap ? (1L << fcv_uses_ibl_specular_map) : 0;
    bitflag |= constants.hasSSAOMap ? (1L << fcv_uses_ssao_map) : 0;
    
    NSNumber *key = @(bitflag);
    id<MTLRenderPipelineState> renderPipelineState = [_shadingPipelineDict objectForKey: key];
    if(renderPipelineState == nil) {
        // make function constant values object
        MTLFunctionConstantValues *constantValues = [MTLFunctionConstantValues new];
        [constantValues setConstantValue: &constants.hasIBLIrradianceMap
                                    type: MTLDataTypeBool
                                 atIndex: fcv_uses_ibl_irradiance_map];
        [constantValues setConstantValue: &constants.hasIBLSpecularMap
                                    type: MTLDataTypeBool
                                 atIndex: fcv_uses_ibl_specular_map];
        [constantValues setConstantValue: &constants.hasSSAOMap
                                    type: MTLDataTypeBool
                                 atIndex: fcv_uses_ssao_map];
        
        _shadingPipelineDescriptor.vertexFunction = [_library newFunctionWithName: @"screen_vert"
                                                                  constantValues: constantValues
                                                                           error: error];
        _shadingPipelineDescriptor.fragmentFunction = [_library newFunctionWithName: @"gbuffer_shade_frag"
                                                                    constantValues: constantValues
                                                                             error: error];
        renderPipelineState = [_device newRenderPipelineStateWithDescriptor: _shadingPipelineDescriptor
                                                                      error: error];
        _shadingPipelineDict[key] = renderPipelineState;
    }
    return renderPipelineState;
}

- (id<MTLRenderPipelineState>)nonLightCulledShadingPipelineStateWithConstants: (MGPGBufferShadingFunctionConstants)constants
                                                                        error: (NSError **)error; {
    if(error != nil) {
        *error = nil;
    }
    
    NSUInteger bitflag = 0;
    bitflag |= constants.hasIBLIrradianceMap ? (1L << fcv_uses_ibl_irradiance_map) : 0;
    bitflag |= constants.hasIBLSpecularMap ? (1L << fcv_uses_ibl_specular_map) : 0;
    bitflag |= constants.hasSSAOMap ? (1L << fcv_uses_ssao_map) : 0;
    
    NSNumber *key = @(bitflag);
    id<MTLRenderPipelineState> renderPipelineState = [_nonLightCulledShadingPipelineDict objectForKey: key];
    if(renderPipelineState == nil) {
        // make function constant values object
        MTLFunctionConstantValues *constantValues = [MTLFunctionConstantValues new];
        [constantValues setConstantValue: &constants.hasIBLIrradianceMap
                                    type: MTLDataTypeBool
                                 atIndex: fcv_uses_ibl_irradiance_map];
        [constantValues setConstantValue: &constants.hasIBLSpecularMap
                                    type: MTLDataTypeBool
                                 atIndex: fcv_uses_ibl_specular_map];
        [constantValues setConstantValue: &constants.hasSSAOMap
                                    type: MTLDataTypeBool
                                 atIndex: fcv_uses_ssao_map];
        
        _shadingPipelineDescriptor.vertexFunction = [_library newFunctionWithName: @"screen_vert"
                                                                  constantValues: constantValues
                                                                           error: error];
        _shadingPipelineDescriptor.fragmentFunction = [_library newFunctionWithName: @"gbuffer_shade_old_frag"
                                                                    constantValues: constantValues
                                                                             error: error];
        renderPipelineState = [_device newRenderPipelineStateWithDescriptor: _shadingPipelineDescriptor
                                                                      error: error];
        _nonLightCulledShadingPipelineDict[key] = renderPipelineState;
    }
    return renderPipelineState;
}

@end
