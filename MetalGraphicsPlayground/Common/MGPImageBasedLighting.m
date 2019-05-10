//
//  MGPImageBasedLighting.m
//  MetalDeferred
//
//  Created by 이현우 on 09/05/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import "MGPImageBasedLighting.h"
#import "MGPMesh.h"

@implementation MGPImageBasedLighting {
    id<MTLDevice> _device;
    id<MTLLibrary> _library;
    id<MTLCommandQueue> _queue;
    
    id<MTLBuffer> _quadVerticesBuffer;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
                       library:(id<MTLLibrary>)library
                         queue:(id<MTLCommandQueue>)queue {
    self = [super init];
    if(self) {
        _device = device;
        _library = library;
        _queue = queue;
        
        _quadVerticesBuffer = [MGPMesh newQuadVerticesBuffer: _device];
        [self _makeEmptyTextures];
    }
    return self;
}

- (void)_makeEmptyTextures {
    NSInteger width = _environmentEquirectangularMap.width;
    NSInteger height = _environmentEquirectangularMap.height;
    
    if(!width) width = 64;
    if(!height) height = 32;
    
    MTLTextureDescriptor *desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatRGBA16Float
                                                                                    width: width
                                                                                   height: height
                                                                                mipmapped: NO];
    desc.usage = MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget;
    if(_environmentEquirectangularMap == nil)
        _environmentEquirectangularMap = [_device newTextureWithDescriptor: desc];
    _irradianceEquirectangularMap = [_device newTextureWithDescriptor: desc];
    _specularEquirectangularMap = [_device newTextureWithDescriptor: desc];
}

- (void)setEnvironmentEquirectangularMap:(id<MTLTexture>)environmentEquirectangularMap {
    _environmentEquirectangularMap = environmentEquirectangularMap;
    [self _makeEmptyTextures];
}

- (void)renderIrradianceMap:(id<MTLCommandBuffer>)buffer {
    MTLRenderPassDescriptor *renderPass = [MTLRenderPassDescriptor new];
    renderPass.colorAttachments[0].texture = _irradianceEquirectangularMap;
    renderPass.colorAttachments[0].loadAction = MTLLoadActionClear;
    renderPass.colorAttachments[0].storeAction = MTLStoreActionStore;
    renderPass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1);
    
    MTLRenderPipelineDescriptor *pipelineDesc = [MTLRenderPipelineDescriptor new];
    pipelineDesc.vertexFunction = [_library newFunctionWithName: @"screen_vert"];
    pipelineDesc.fragmentFunction = [_library newFunctionWithName: @"irradiance_frag"];
    pipelineDesc.colorAttachments[0].pixelFormat = _irradianceEquirectangularMap.pixelFormat;
    pipelineDesc.label = @"Irradiance Map";
    id<MTLRenderPipelineState> renderPipeline = [_device newRenderPipelineStateWithDescriptor: pipelineDesc
                                                                                         error: nil];
    
    id<MTLRenderCommandEncoder> enc = [buffer renderCommandEncoderWithDescriptor: renderPass];
    enc.label = @"Irradiance Map";
    [enc setRenderPipelineState: renderPipeline];
    [enc setVertexBuffer: _quadVerticesBuffer
                  offset: 0
                 atIndex: 0];
    [enc setFragmentTexture: _environmentEquirectangularMap
                    atIndex: 0];
    [enc drawPrimitives: MTLPrimitiveTypeTriangle
            vertexStart: 0
            vertexCount: 6];
    [enc endEncoding];
}

- (void)renderSpecularLightingMap:(id<MTLCommandBuffer>)buffer {
    // TODO
}

@end
