//
//  AppDelegate.m
//  MetalIZBShadow
//
//  Created by 이현우 on 2016. 6. 19..
//  Copyright © 2016년 Prin_E. All rights reserved.
//

#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <ModelIO/ModelIO.h>
#import "AppDelegate.h"
#import "../Common/Sources/Utility/MetalMath.h"
#import "../Common/Sources/View/MGPView.h"
#import "SharedStructures.h"

typedef NS_OPTIONS(NSInteger, MDepthMapType) {
    MDepthMapTypeNone,
    MDepthMapTypeLightView,
    MDepthMapTypeEyeView
};

@interface AppDelegate () {
    id<MTLDevice> _device;
    id<MTLLibrary> _library;
    id<MTLCommandQueue> _queue;
    
    dispatch_semaphore_t _semaphore;
    
    id<MTLBuffer> _uniformBuffer;
    id<MTLBuffer> _circleBuffer;
    id<MTLBuffer> _planeBuffer;
    NSUInteger _currentThread;
    uniform_t _uniform;
    
    id<MTLRenderPipelineState> _shadowMapCirclePipeline;
    id<MTLRenderPipelineState> _shadowMapPlanePipeline;
    MTLRenderPassDescriptor *_shadowMapPass;
    id<MTLTexture> _shadowMapTexture;
    
    MTKMesh *_circle;
    MTKMesh *_plane;
    id<MTLRenderPipelineState> _circlePipeline;
    id<MTLRenderPipelineState> _planePipeline;
    id<MTLDepthStencilState> _depthState;
    
    id<MTLRenderPipelineState> _izbEyeViewDepthCirclePipeline;
    id<MTLRenderPipelineState> _izbEyeViewDepthPlanePipeline;
    id<MTLComputePipelineState> _izbDepthComputePipeline;
    
    // IZB buffer
    id<MTLTexture> _izHeadTex;
    id<MTLBuffer> _izBuffer;
    
    float _r;
    float _r2;
}

@property (weak) IBOutlet MTKView *view;
@property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [self _initMetal];
    [self _initMetalView];
    [self _initAssets];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

- (void)_initMetal {
    _device = MTLCreateSystemDefaultDevice();
    _library = [_device newDefaultLibrary];
    _queue = [_device newCommandQueue];
    
    _semaphore = dispatch_semaphore_create(3);
}

- (void)_initMetalView {
    _view.device = _device;
    _view.delegate = self;
    _view.preferredFramesPerSecond = 60;
    _view.sampleCount = 1;
    _view.depthStencilPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
}

- (void)_initAssets {
    _uniformBuffer = [_device newBufferWithLength: sizeof(uniform_t) * 3 options: 0];
    _circleBuffer = [_device newBufferWithLength: sizeof(transform_t) * 3 options: 0];
    _planeBuffer = [_device newBufferWithLength: sizeof(transform_t) * 3 options: 0];
    
    NSError *err = nil;
    
    MTKMeshBufferAllocator *allocator = [[MTKMeshBufferAllocator alloc] initWithDevice: _device];
    MDLMesh *mesh = [MDLMesh newEllipsoidWithRadii: vector3(1.0f, 1.0f, 1.0f)
                                    radialSegments: 5
                                  verticalSegments: 30
                                      geometryType: MDLGeometryTypeTriangles
                                     inwardNormals: NO
                                        hemisphere: NO
                                         allocator: allocator];
    _circle = [[MTKMesh alloc] initWithMesh: mesh device: _device error: nil];

    mesh = [MDLMesh newBoxWithDimensions: vector3(20.0f, 0.1f, 20.0f)
                                segments: vector3(20u, 20u, 20u)
                            geometryType: MDLGeometryTypeTriangles
                           inwardNormals: NO
                               allocator: allocator];
    
    _plane = [[MTKMesh alloc] initWithMesh: mesh device: _device error: nil];
    
    MTLRenderPipelineDescriptor *pd = [[MTLRenderPipelineDescriptor alloc] init];
    pd.vertexFunction = [_library newFunctionWithName: @"vert"];
    pd.fragmentFunction = [_library newFunctionWithName: @"frag"];
    pd.sampleCount = 1;
    pd.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
    pd.stencilAttachmentPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
    pd.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    pd.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(_circle.vertexDescriptor);
    _circlePipeline = [_device newRenderPipelineStateWithDescriptor: pd error: nil];
    pd.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(_plane.vertexDescriptor);
    _planePipeline = [_device newRenderPipelineStateWithDescriptor: pd error: nil];
    
    MTLDepthStencilDescriptor *depthDesc = [[MTLDepthStencilDescriptor alloc] init];
    [depthDesc setDepthCompareFunction: MTLCompareFunctionLess];
    depthDesc.depthWriteEnabled = YES;
    _depthState = [_device newDepthStencilStateWithDescriptor: depthDesc];
    
    // shadow map
    pd = [[MTLRenderPipelineDescriptor alloc] init];
    pd.vertexFunction = [_library newFunctionWithName: @"shadowmap_vert"];
    pd.fragmentFunction = nil;
    pd.sampleCount = 1;
    pd.colorAttachments[0].pixelFormat = MTLPixelFormatInvalid;
    pd.stencilAttachmentPixelFormat = MTLPixelFormatInvalid;
    pd.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float;
    pd.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(_circle.vertexDescriptor);
    _shadowMapCirclePipeline = [_device newRenderPipelineStateWithDescriptor: pd error: &err];
    pd.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(_plane.vertexDescriptor);
    _shadowMapPlanePipeline = [_device newRenderPipelineStateWithDescriptor: pd error: &err];
    
    // IZB Eye-view depth
    pd = [MTLRenderPipelineDescriptor new];
    pd.vertexFunction = [_library newFunctionWithName: @"izb_eyeviewdepth_vert"];
    pd.fragmentFunction = nil;
    pd.sampleCount = 1;
    pd.colorAttachments[0].pixelFormat = MTLPixelFormatInvalid;
    pd.stencilAttachmentPixelFormat = MTLPixelFormatInvalid;
    pd.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float;
    pd.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(_circle.vertexDescriptor);
    _izbEyeViewDepthCirclePipeline = [_device newRenderPipelineStateWithDescriptor: pd error: &err];
    pd.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(_plane.vertexDescriptor);
    _izbEyeViewDepthPlanePipeline = [_device newRenderPipelineStateWithDescriptor: pd error: &err];
    
    id<MTLFunction> izbCompDepthFunc = [_library newFunctionWithName: @"izb_compute_depth"];
    _izbDepthComputePipeline = [_device newComputePipelineStateWithFunction: izbCompDepthFunc error: nil];
    
    MTLTextureDescriptor *shadowMapTextureDesc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatDepth32Float
                                                                                                    width: 1024
                                                                                                   height: 1024
                                                                                                mipmapped: NO];
    shadowMapTextureDesc.storageMode = MTLStorageModePrivate;
    shadowMapTextureDesc.usage = MTLTextureUsagePixelFormatView | MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget;
    _shadowMapTexture = [_device newTextureWithDescriptor: shadowMapTextureDesc];
    
    _shadowMapPass = [[MTLRenderPassDescriptor alloc] init];
    _shadowMapPass.depthAttachment.texture = _shadowMapTexture;
    _shadowMapPass.depthAttachment.loadAction = MTLLoadActionClear;
    _shadowMapPass.depthAttachment.storeAction = MTLStoreActionStore;
    
    // default values
    CGFloat w = _view.drawableSize.width;
    CGFloat h = _view.drawableSize.height;
    _uniform.projection = matrix_from_perspective_fov_aspectLH(45.0f, w/h, 0.01f, 100.0f);
    _uniform.view = matrix_lookat(vector3(0.0f, 5.0f, -5.0f), vector3(0.0f, 0.0f, 0.0f), vector3(0.0f, 1.0f, 0.0f));
    
    // irregular z buffer
    _izHeadTex = [_device newTextureWithDescriptor: [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatR32Sint
                                                                                                       width: _view.drawableSize.width
                                                                                                      height: _view.drawableSize.height
                                                                                                   mipmapped: NO]];
    _izBuffer = [_device newBufferWithLength: _view.drawableSize.width * _view.drawableSize.height * sizeof(iz_buffer_t) options: MTLResourceStorageModePrivate];
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    _uniform.projection = matrix_from_perspective_fov_aspectLH(45.0f, size.width/size.height, 0.01f, 100.0f);
}

- (void)drawInMTKView:(MTKView *)view {
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    
    [self _prepareBuffer];
    id<MTLCommandBuffer> buffer = [_queue commandBuffer];
    id<MTLRenderCommandEncoder> enc = nil;
    
    // Shadow
    enc = [buffer renderCommandEncoderWithDescriptor: _shadowMapPass];
    [enc setLabel: @"Shadow"];
    [enc setDepthStencilState: _depthState];
    [self _draw: enc isShadowMap: YES depthMapType: MDepthMapTypeLightView];
    [enc endEncoding];
    
    // Render
    MTLRenderPassDescriptor *renderPass = _view.currentRenderPassDescriptor;
    renderPass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1);
    
    enc = [buffer renderCommandEncoderWithDescriptor: renderPass];
    [enc setLabel: @"Draw"];
    [enc setDepthStencilState: _depthState];
    [self _draw: enc isShadowMap: NO depthMapType: MDepthMapTypeLightView];
    [enc endEncoding];
    
    [buffer addCompletedHandler: ^(id<MTLCommandBuffer> b) {
        dispatch_semaphore_signal(self->_semaphore);
    }];
    [buffer presentDrawable: _view.currentDrawable];
    [buffer commit];
    
    _currentThread = (_currentThread + 1) % 3;
    _r += 0.01f;
    _r2 += 0.015f;
    if(_r2 > 6.28)
        _r2 -= 6.28;
}

- (void)_prepareBuffer {
    _uniform.lightPos = vector4(cosf(_r2) * 5.0f, 5.0f, sinf(_r2) * 5.0f, 0.0f);
    _uniform.lightIntensity = (cosf(_r2) + 3.0f) * 0.25f;
    _uniform.lightColor = vector4((cosf(_r2) + 3.0f) * 0.25f, (sinf(_r2) + 3.0f) * 0.25f, 1.0f, 1.0f);
    _uniform.lightView = matrix_lookat(vector3(_uniform.lightPos.x, _uniform.lightPos.y, _uniform.lightPos.z), vector3(0.0f, 0.0f, 0.0f), vector3(0.0f, 1.0f, 0.0f));
    _uniform.lightProjection = matrix_from_perspective_fov_aspectLH(45.0f, _view.drawableSize.width/_view.drawableSize.height, 1.0f, 40.0f);
    memcpy([_uniformBuffer contents] + _currentThread * sizeof _uniform, &_uniform, sizeof _uniform);
    
    transform_t tf;
    tf.model = matrix_from_rotation(_r, 0.0f, 1.0f, 0.0f);
    tf.albedo = vector4(1.0f, 1.0f, 1.0f, 1.0f);
    memcpy([_circleBuffer contents] + _currentThread * sizeof tf, &tf, sizeof tf);
    tf.model = matrix_multiply(matrix_from_translation(0, -3, 0), matrix_from_rotation(M_PI, 1.0f, 0.0f, 0.0f));
    tf.albedo = vector4(0.799f, 0.811f, 1.0f, 1.0f);
    memcpy([_planeBuffer contents] + _currentThread * sizeof tf, &tf, sizeof tf);
    
}

- (void)_computeIZB_Depth: (id<MTLCommandBuffer>)buffer {
    id<MTLRenderCommandEncoder> enc = [buffer renderCommandEncoderWithDescriptor: _shadowMapPass];
    [enc setLabel: @"IZB Depth (Eye View)"];
    [enc setDepthStencilState: _depthState];
    [self _draw: enc isShadowMap: YES depthMapType: MDepthMapTypeEyeView];
    [enc endEncoding];
}

- (void)_computeIZB_LightView: (id<MTLCommandBuffer>)buffer {
    
}

- (void)_draw: (id<MTLRenderCommandEncoder>)enc isShadowMap: (BOOL)isShadowMap depthMapType: (MDepthMapType)depthMapType {
    [enc setVertexBuffer: _uniformBuffer offset: _currentThread * sizeof(uniform_t) atIndex: 1];
    [enc setFragmentBuffer: _uniformBuffer offset: _currentThread * sizeof(uniform_t) atIndex: 1];
    
    if(!isShadowMap) {
        [enc setFragmentTexture: _shadowMapTexture atIndex: 0];
    }
    
    // circle
    id<MTLRenderPipelineState> circlePipeline = _circlePipeline;
    if(isShadowMap) circlePipeline = _shadowMapCirclePipeline;
    [enc setRenderPipelineState: circlePipeline];
    [enc setVertexBuffer: _circle.vertexBuffers[0].buffer offset: _circle.vertexBuffers[0].offset atIndex: 0];
    [enc setVertexBuffer: _circleBuffer offset: _currentThread * sizeof(transform_t) atIndex: 2];
    [enc setFragmentBuffer: _circleBuffer offset: _currentThread * sizeof(transform_t) atIndex: 2];
    for(NSInteger i = 0; i < _circle.submeshes.count; i++) {
        MTKSubmesh *submesh = _circle.submeshes[i];
        [enc drawIndexedPrimitives:submesh.primitiveType
                        indexCount:submesh.indexCount
                         indexType:submesh.indexType
                       indexBuffer:submesh.indexBuffer.buffer
                 indexBufferOffset:submesh.indexBuffer.offset];
    }
    
    // plane
    id<MTLRenderPipelineState> planePipeline = _planePipeline;
    if(isShadowMap) planePipeline = _shadowMapPlanePipeline;
    [enc setRenderPipelineState: planePipeline];
    [enc setVertexBuffer: _plane.vertexBuffers[0].buffer offset: _plane.vertexBuffers[0].offset atIndex: 0];
    [enc setVertexBuffer: _planeBuffer offset: _currentThread * sizeof(transform_t) atIndex: 2];
    [enc setFragmentBuffer: _planeBuffer offset: _currentThread * sizeof(transform_t) atIndex: 2];
    for(NSInteger i = 0; i < _plane.submeshes.count; i++) {
        MTKSubmesh *submesh = _plane.submeshes[i];
        [enc drawIndexedPrimitives:submesh.primitiveType
                        indexCount:submesh.indexCount
                         indexType:submesh.indexType
                       indexBuffer:submesh.indexBuffer.buffer
                 indexBufferOffset:submesh.indexBuffer.offset];
    }
}

@end
