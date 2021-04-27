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
    MTLRenderPassDescriptor *_indirectLightingPassDescriptor;
    MTLRenderPassDescriptor *_directionalShadowedLightingPassDescriptor;
    MTLRenderPassDescriptor *_shadingPassDescriptor;
    MTLRenderPipelineDescriptor *_renderPipelineDescriptor;
    MTLRenderPipelineDescriptor *_lightingPipelineDescriptor;
    MTLRenderPipelineDescriptor *_indirectLightingPipelineDescriptor;
    MTLRenderPipelineDescriptor *_directionalShadowedLightingPipelineDescriptor;
    MTLRenderPipelineDescriptor *_shadingPipelineDescriptor;
    
    // key : big-flag of attachment types
    // value : render-pass descriptors
    NSMutableDictionary<NSNumber *, MTLRenderPassDescriptor *> *_prePassDescriptorDict;
    
    // key : bit-flag of function constant values
    // value : render-pipeline state
    NSMutableDictionary<NSNumber *, id<MTLRenderPipelineState>> *_renderPipelineDict;
    id<MTLRenderPipelineState> _lightingPipelineState;
    NSMutableDictionary<NSNumber *, id<MTLRenderPipelineState>> *_lightingPipelineDict;
    NSMutableDictionary<NSNumber *, id<MTLRenderPipelineState>> *_shadingPipelineDict;
    NSMutableDictionary<NSNumber *, id<MTLRenderPipelineState>> *_indirectLightingPipelineDict;
    NSMutableDictionary<NSNumber *, id<MTLRenderPipelineState>> *_directionalShadowedLightingPipelineDict;
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
    _attachments = attachments;
    
    _prePassDescriptorDict = [NSMutableDictionary dictionaryWithCapacity:4];
    
    _renderPipelineDict = [NSMutableDictionary dictionaryWithCapacity:24];
    _lightingPipelineDict = [NSMutableDictionary dictionaryWithCapacity:8];
    _shadingPipelineDict = [NSMutableDictionary dictionaryWithCapacity:4];
    _indirectLightingPipelineDict = [NSMutableDictionary dictionaryWithCapacity:4];
    _directionalShadowedLightingPipelineDict = [NSMutableDictionary dictionaryWithCapacity:4];
    _nonLightCulledShadingPipelineDict = [NSMutableDictionary dictionaryWithCapacity:4];
    
    [self _makeGBufferTextures];
    [self _makeBaseVertexDescriptor];
    [self _makeRenderPipelineDescriptor];
    [self _makeLightingPipelineDescriptor];
    [self _makeIndirectLightingPipelineDescriptor];
    [self _makeDirectionalShadowedLightingPipelineDescriptor];
    [self _makeShadingPipelineDescriptor];
    [self _assignPassDescriptorTextures];
    [self _makeLightingPassDescriptor];
    [self _makeIndirectLightingPassDescriptor];
    [self _makeDirectionalShadowedLightingPassDescriptor];
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
    
    if(_attachments & MGPGBufferAttachmentTypeAlbedo) {
        desc.pixelFormat = MTLPixelFormatBGRA8Unorm;
        _albedo = [_device newTextureWithDescriptor: desc];
        _albedo.label = @"Albedo G-buffer";
    }
    else {
        _albedo = nil;
    }
    
    // normal
    if(_attachments & MGPGBufferAttachmentTypeNormal) {
        desc.pixelFormat = MTLPixelFormatRGB10A2Unorm;
        _normal = [_device newTextureWithDescriptor: desc];
        _normal.label = @"Normal G-buffer";
    }
    else {
        _normal = nil;
    }
    
    // depth
    if(_attachments & MGPGBufferAttachmentTypeDepth) {
        desc.pixelFormat = MTLPixelFormatDepth32Float_Stencil8;
        _depth = [_device newTextureWithDescriptor: desc];
        _depth.label = @"Depth G-buffer";
    }
    else {
        _depth = nil;
    }
    
    // shading
    if(_attachments & MGPGBufferAttachmentTypeShading) {
        desc.pixelFormat = MTLPixelFormatBGRA8Unorm;
        _shading = [_device newTextureWithDescriptor: desc];
        _shading.label = @"Shading G-buffer";
    }
    else {
        _shading = nil;
    }
    
    // tangent
    if(_attachments & MGPGBufferAttachmentTypeTangent) {
        desc.pixelFormat = MTLPixelFormatRGB10A2Unorm;
        _tangent = [_device newTextureWithDescriptor: desc];
        _tangent.label = @"Tangent G-buffer";
    }
    else {
        _tangent = nil;
    }
    
    // lighting
    if(_attachments & MGPGBufferAttachmentTypeLighting) {
        desc.pixelFormat = MTLPixelFormatRGBA16Float;
        _lighting = [_device newTextureWithDescriptor: desc];
        _lighting.label = @"Light Accumulation G-buffer";
    }
    else {
        _lighting = nil;
    }
    
    // shade-output
    if(_attachments & MGPGBufferAttachmentTypeOutput) {
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
    _baseVertexDescriptor.layouts[0].stepFunction = MTLVertexStepFunctionPerVertex;
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


- (void)_makeIndirectLightingPipelineDescriptor {
    MTLRenderPipelineDescriptor *desc = [[MTLRenderPipelineDescriptor alloc] init];
    desc.label = @"Indirect Lighting";
    desc.colorAttachments[0].pixelFormat = _output.pixelFormat;
    desc.colorAttachments[0].blendingEnabled = YES;
    desc.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
    desc.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
    desc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorOne;
    desc.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOne;
    desc.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorZero;
    desc.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOne;
    _indirectLightingPipelineDescriptor = desc;
}

- (void)_makeDirectionalShadowedLightingPipelineDescriptor {
    MTLRenderPipelineDescriptor *desc = [[MTLRenderPipelineDescriptor alloc] init];
    desc.label = @"Directional Shadowed Lighting";
    desc.colorAttachments[0].pixelFormat = _output.pixelFormat;
    desc.colorAttachments[0].blendingEnabled = YES;
    desc.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
    desc.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
    desc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorOne;
    desc.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOne;
    desc.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorZero;
    desc.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOne;
    _directionalShadowedLightingPipelineDescriptor = desc;
}

- (void)_makeShadingPipelineDescriptor {
    MTLRenderPipelineDescriptor *desc = [[MTLRenderPipelineDescriptor alloc] init];
    desc.label = @"Shading";
    desc.colorAttachments[0].pixelFormat = _output.pixelFormat;
    _shadingPipelineDescriptor = desc;
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

- (void)_makeIndirectLightingPassDescriptor {
    if(_indirectLightingPassDescriptor == nil) {
        _indirectLightingPassDescriptor = [[MTLRenderPassDescriptor alloc] init];
        
        // color attachments
        _indirectLightingPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionLoad;
        _indirectLightingPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    }
    
    _indirectLightingPassDescriptor.colorAttachments[0].texture = _output;
}

- (void)_makeDirectionalShadowedLightingPassDescriptor {
    if(_directionalShadowedLightingPassDescriptor == nil) {
        _directionalShadowedLightingPassDescriptor = [[MTLRenderPassDescriptor alloc] init];
        
        // color attachments
        _directionalShadowedLightingPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionLoad;
        _directionalShadowedLightingPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    }
    
    _directionalShadowedLightingPassDescriptor.colorAttachments[0].texture = _output;
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
    return [self prePassDescriptorWithAttachment:_attachments];
}

- (MTLRenderPassDescriptor *)lightingPassBaseDescriptor {
    return _lightingPassBaseDescriptor;
}

- (MTLRenderPassDescriptor *)lightingPassAddDescriptor {
    return _lightingPassAddDescriptor;
}

- (MTLRenderPassDescriptor *)indirectLightingPassDescriptor {
    return _indirectLightingPassDescriptor;
}

- (MTLRenderPassDescriptor *)directionalShadowedLightingPassDescriptor {
    return _directionalShadowedLightingPassDescriptor;
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
    [self _removeRenderPassDescriptorCaches];
}

#pragma mark - Resize
- (void)resize:(CGSize)newSize {
    NSUInteger width = newSize.width;
    NSUInteger height = newSize.height;
    if(_albedo.width != width || _albedo.height != height) {
        _size = newSize;
        [self _makeGBufferTextures];
        [self _assignPassDescriptorTextures];
        [self _makeLightingPassDescriptor];
        [self _makeIndirectLightingPassDescriptor];
        [self _makeDirectionalShadowedLightingPassDescriptor];
        [self _makeShadingPassDescriptor];
    }
}

#pragma mark - Render passes
- (void)_assignPassDescriptorTexturesInPassDescriptorDict:(NSDictionary<NSNumber*,MTLRenderPassDescriptor*> *)dict {
    NSArray<NSNumber*> *keys = dict.allKeys;
    for(NSNumber *key in keys) {
        MGPGBufferAttachmentType attachments = key.unsignedIntegerValue;
        MTLRenderPassDescriptor *renderPass = dict[key];
        
        if(attachments & MGPGBufferAttachmentTypeAlbedo)
            renderPass.colorAttachments[attachment_albedo].texture = _albedo;
        else
            renderPass.colorAttachments[attachment_albedo].texture = nil;
        
        if(attachments & MGPGBufferAttachmentTypeNormal)
            renderPass.colorAttachments[attachment_normal].texture = _normal;
        else
            renderPass.colorAttachments[attachment_normal].texture = nil;
        
        if(attachments & MGPGBufferAttachmentTypeShading)
            renderPass.colorAttachments[attachment_shading].texture = _shading;
        else
            renderPass.colorAttachments[attachment_shading].texture = nil;
        
        if(attachments & MGPGBufferAttachmentTypeTangent)
            renderPass.colorAttachments[attachment_tangent].texture = _tangent;
        else
            renderPass.colorAttachments[attachment_tangent].texture = nil;
        
        if(attachments & MGPGBufferAttachmentTypeLighting)
            renderPass.colorAttachments[attachment_light].texture = _tangent;
        else
            renderPass.colorAttachments[attachment_light].texture = nil;
        
        if(attachments & MGPGBufferAttachmentTypeDepth)
            renderPass.depthAttachment.texture = _depth;
        else
            renderPass.depthAttachment.texture = nil;
    }
}

- (void)_assignPassDescriptorTextures {
    [self _assignPassDescriptorTexturesInPassDescriptorDict:_prePassDescriptorDict];
}

- (void)_removeRenderPassDescriptorCaches {
    NSArray<NSNumber*> *keys = _prePassDescriptorDict.allKeys;
    for(NSNumber *key in keys) {
        MGPGBufferAttachmentType attachments = key.unsignedIntegerValue;
        if((attachments & (~_attachments)) != 0) {
            [_prePassDescriptorDict removeObjectForKey:key];
        }
    }
}

- (MTLRenderPassDescriptor *)prePassDescriptorWithAttachment:(MGPGBufferAttachmentType)attachments {
    NSNumber *key = @(attachments);
    MTLRenderPassDescriptor *renderPass = [_prePassDescriptorDict objectForKey:key];
    if(renderPass == nil) {
        renderPass = [[MTLRenderPassDescriptor alloc] init];
        
        // color attachments
        if(attachments & MGPGBufferAttachmentTypeAlbedo) {
            renderPass.colorAttachments[attachment_albedo].loadAction = MTLLoadActionClear;
            renderPass.colorAttachments[attachment_albedo].storeAction = MTLStoreActionStore;
            renderPass.colorAttachments[attachment_albedo].clearColor = MTLClearColorMake(0, 0, 0, 0);
        }
        if(attachments & MGPGBufferAttachmentTypeNormal) {
            renderPass.colorAttachments[attachment_normal].loadAction = MTLLoadActionClear;
            renderPass.colorAttachments[attachment_normal].storeAction = MTLStoreActionStore;
            renderPass.colorAttachments[attachment_normal].clearColor = MTLClearColorMake(0, 0, 0, 0);
        }
        if(attachments & MGPGBufferAttachmentTypeShading) {
            renderPass.colorAttachments[attachment_shading].loadAction = MTLLoadActionClear;
            renderPass.colorAttachments[attachment_shading].storeAction = MTLStoreActionStore;
            renderPass.colorAttachments[attachment_shading].clearColor = MTLClearColorMake(0, 0, 0, 0);
        }
        if(attachments & MGPGBufferAttachmentTypeTangent) {
            renderPass.colorAttachments[attachment_tangent].loadAction = MTLLoadActionClear;
            renderPass.colorAttachments[attachment_tangent].storeAction = MTLStoreActionStore;
            renderPass.colorAttachments[attachment_tangent].clearColor = MTLClearColorMake(0, 0, 0, 0);
        }
        if(attachments & MGPGBufferAttachmentTypeDepth) {
            renderPass.depthAttachment.loadAction = MTLLoadActionClear;
            renderPass.depthAttachment.storeAction = MTLStoreActionStore;
        }
        
        // assign or replace textures
        if(attachments & MGPGBufferAttachmentTypeAlbedo)
            renderPass.colorAttachments[attachment_albedo].texture = _albedo;
        if(attachments & MGPGBufferAttachmentTypeNormal)
            renderPass.colorAttachments[attachment_normal].texture = _normal;
        if(attachments & MGPGBufferAttachmentTypeShading)
            renderPass.colorAttachments[attachment_shading].texture = _shading;
        if(attachments & MGPGBufferAttachmentTypeTangent)
            renderPass.colorAttachments[attachment_tangent].texture = _tangent;
        if(attachments & MGPGBufferAttachmentTypeDepth)
            renderPass.depthAttachment.texture = _depth;
    }

    return renderPass;
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
    bitflag |= constants.usesAnisotropy ? (1L << fcv_uses_anisotropy) : 0;
    
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
        [constantValues setConstantValue: &constants.usesAnisotropy
                                    type: MTLDataTypeBool
                                 atIndex: fcv_uses_anisotropy];
        
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

- (id<MTLRenderPipelineState>)renderPipelineStateWithConstants:(MGPGBufferPrepassFunctionConstants)constants
                                                   attachments:(MGPGBufferAttachmentType)attachments
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
    bitflag |= constants.usesAnisotropy ? (1L << fcv_uses_anisotropy) : 0;
    
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
        [constantValues setConstantValue: &constants.usesAnisotropy
                                    type: MTLDataTypeBool
                                 atIndex: fcv_uses_anisotropy];
        
        _renderPipelineDescriptor.vertexFunction = [_library newFunctionWithName: @"gbuffer_prepass_vert"
                                                                  constantValues: constantValues
                                                                           error: error];
        _renderPipelineDescriptor.fragmentFunction = [_library newFunctionWithName: @"gbuffer_prepass_frag"
                                                                    constantValues: constantValues
                                                                             error: error];
        
        if(attachments & MGPGBufferAttachmentTypeAlbedo)
            _renderPipelineDescriptor.colorAttachments[attachment_albedo].pixelFormat = _albedo.pixelFormat;
        else
            _renderPipelineDescriptor.colorAttachments[attachment_albedo].pixelFormat = MTLPixelFormatInvalid;
        
        if(attachments & MGPGBufferAttachmentTypeNormal)
            _renderPipelineDescriptor.colorAttachments[attachment_normal].pixelFormat = _normal.pixelFormat;
        else
            _renderPipelineDescriptor.colorAttachments[attachment_normal].pixelFormat = MTLPixelFormatInvalid;
        
        if(attachments & MGPGBufferAttachmentTypeShading)
            _renderPipelineDescriptor.colorAttachments[attachment_shading].pixelFormat = _shading.pixelFormat;
        else
            _renderPipelineDescriptor.colorAttachments[attachment_shading].pixelFormat = MTLPixelFormatInvalid;
        
        if(attachments & MGPGBufferAttachmentTypeTangent)
            _renderPipelineDescriptor.colorAttachments[attachment_tangent].pixelFormat = _tangent.pixelFormat;
        else
            _renderPipelineDescriptor.colorAttachments[attachment_tangent].pixelFormat = MTLPixelFormatInvalid;
        
        if(attachments & MGPGBufferAttachmentTypeDepth)
            _renderPipelineDescriptor.depthAttachmentPixelFormat = _depth.pixelFormat;
        else
            _renderPipelineDescriptor.depthAttachmentPixelFormat = MTLPixelFormatInvalid;
        
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

- (id<MTLRenderPipelineState>)lightingPipelineStateWithConstants:(MGPGBufferShadingFunctionConstants)constants
                                                           error: (NSError **)error {
    if(error != nil) {
        *error = nil;
    }
    
    NSUInteger bitflag = 0;
    bitflag |= constants.usesAnisotropy ? (1L << fcv_uses_anisotropy) : 0;
    
    NSNumber *key = @(bitflag);
    id<MTLRenderPipelineState> renderPipelineState = [_lightingPipelineDict objectForKey: key];
    if(renderPipelineState == nil) {
        // make function constant values object
        MTLFunctionConstantValues *constantValues = [MTLFunctionConstantValues new];
        [constantValues setConstantValue: &constants.usesAnisotropy
                                    type: MTLDataTypeBool
                                 atIndex: fcv_uses_anisotropy];
        
        _lightingPipelineDescriptor.vertexFunction = [_library newFunctionWithName: @"screen_vert"
                                                                  constantValues: constantValues
                                                                           error: error];
        _lightingPipelineDescriptor.fragmentFunction = [_library newFunctionWithName: @"gbuffer_light_frag"
                                                                    constantValues: constantValues
                                                                             error: error];
        renderPipelineState = [_device newRenderPipelineStateWithDescriptor: _lightingPipelineDescriptor
                                                                      error: error];
        _lightingPipelineDict[key] = renderPipelineState;
    }
    return renderPipelineState;
}

- (id<MTLRenderPipelineState>)indirectLightingPipelineStateWithConstants:(MGPGBufferShadingFunctionConstants)constants
                                                                   error:(NSError **)error; {
    if(error != nil) {
        *error = nil;
    }
    
    NSUInteger bitflag = 0;
    bitflag |= constants.hasIBLIrradianceMap ? (1L << fcv_uses_ibl_irradiance_map) : 0;
    bitflag |= constants.hasIBLSpecularMap ? (1L << fcv_uses_ibl_specular_map) : 0;
    bitflag |= constants.hasSSAOMap ? (1L << fcv_uses_ssao_map) : 0;
    bitflag |= constants.usesAnisotropy ? (1L << fcv_uses_anisotropy) : 0;
    
    NSNumber *key = @(bitflag);
    id<MTLRenderPipelineState> renderPipelineState = [_indirectLightingPipelineDict objectForKey: key];
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
        [constantValues setConstantValue: &constants.usesAnisotropy
                                    type: MTLDataTypeBool
                                 atIndex: fcv_uses_anisotropy];
        
        _indirectLightingPipelineDescriptor.vertexFunction = [_library newFunctionWithName: @"screen_vert"
                                                                            constantValues: constantValues
                                                                                     error: error];
        _indirectLightingPipelineDescriptor.fragmentFunction = [_library newFunctionWithName: @"gbuffer_indirect_light_frag"
                                                                              constantValues: constantValues
                                                                                       error: error];
        renderPipelineState = [_device newRenderPipelineStateWithDescriptor: _indirectLightingPipelineDescriptor
                                                                      error: error];
        _indirectLightingPipelineDict[key] = renderPipelineState;
    }
    return renderPipelineState;
}

- (id<MTLRenderPipelineState>)directionalShadowedLightingPipelineStateWithConstants:(MGPGBufferShadingFunctionConstants)constants
                                                                              error:(NSError **)error; {
    if(error != nil) {
        *error = nil;
    }
    
    NSUInteger bitflag = 0;
    bitflag |= constants.usesAnisotropy ? (1L << fcv_uses_anisotropy) : 0;
    
    NSNumber *key = @(bitflag);
    id<MTLRenderPipelineState> renderPipelineState = [_directionalShadowedLightingPipelineDict objectForKey: key];
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
        [constantValues setConstantValue: &constants.usesAnisotropy
                                    type: MTLDataTypeBool
                                 atIndex: fcv_uses_anisotropy];
        
        _directionalShadowedLightingPipelineDescriptor.vertexFunction = [_library newFunctionWithName: @"screen_vert"
                                                                                       constantValues: constantValues
                                                                                                error: error];
        _directionalShadowedLightingPipelineDescriptor.fragmentFunction = [_library newFunctionWithName: @"gbuffer_directional_shadowed_light_frag"
                                                                                         constantValues: constantValues
                                                                                                  error: error];
        renderPipelineState = [_device newRenderPipelineStateWithDescriptor: _directionalShadowedLightingPipelineDescriptor
                                                                      error: error];
        _directionalShadowedLightingPipelineDict[key] = renderPipelineState;
    }
    return renderPipelineState;
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
    bitflag |= constants.usesAnisotropy ? (1L << fcv_uses_anisotropy) : 0;
    
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
        [constantValues setConstantValue: &constants.usesAnisotropy
                                    type: MTLDataTypeBool
                                 atIndex: fcv_uses_anisotropy];
        
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
    bitflag |= constants.usesAnisotropy ? (1L << fcv_uses_anisotropy) : 0;
    
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
        [constantValues setConstantValue: &constants.usesAnisotropy
                                    type: MTLDataTypeBool
                                 atIndex: fcv_uses_anisotropy];
        
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
