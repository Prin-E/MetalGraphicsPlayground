//
//  AppDelegate.m
//  MetalModels
//
//  Created by 이현우 on 2015. 9. 15..
//  Copyright © 2015년 Prin_E. All rights reserved.
//

#import "AppDelegate.h"
#import "MyView.h"
#import "SharedStructures.h"

@interface AppDelegate () {
    id<MTLDevice> _device;
    id<MTLLibrary> _library;
    id<MTLCommandQueue> _queue;
    
    id<MTLBuffer> _vertexBuffer;
    id<MTLBuffer> _indexBuffer;
    
    MTLRenderPassDescriptor *_renderPassDesc;
    id<MTLRenderPipelineState> _pipelineState;
    id<MTLRenderPipelineState> _pipelineState2;
    id<MTLDepthStencilState> _depthState;
    
    id<MTLBuffer> _uniformBuffer;
    
    MTKMesh *_mtkMesh;
    MTKMesh *_legoMesh;
    
    dispatch_semaphore_t semaphore;
    
    uniform_t uniform;
    NSUInteger _currentThread;
    
    float _rot;
}
@property (weak) IBOutlet NSWindow *window;
@property (weak) IBOutlet MyView *view;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    [self _initMetal];
    [self _initView];
    [self _initAssets];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

#pragma mark - Metal View

- (void)_initMetal {
    _device = MTLCreateSystemDefaultDevice();
    _library = [_device newDefaultLibrary];
    _queue = [_device newCommandQueue];
    
    semaphore = dispatch_semaphore_create(3);
}

- (void)_initAssets {
    NSError *err = nil;
    
    MDLMesh *mesh = [MDLMesh newBoxWithDimensions: vector3(2.0f, 2.0f, 2.0f)
                                  segments: vector3(1u, 1u, 1u)
                              geometryType: MDLGeometryTypeTriangles
                             inwardNormals: NO
                                 allocator: [[MTKMeshBufferAllocator alloc] initWithDevice: _device]];
    MTKMesh *mtkMesh = [[MTKMesh alloc] initWithMesh: mesh device: _device error: nil];
    _mtkMesh = mtkMesh;
    
    MDLAsset *legoAsset = [[MDLAsset alloc] initWithURL: [[NSBundle mainBundle] URLForResource: @"lego" withExtension: @"obj"] vertexDescriptor: nil bufferAllocator: [[MTKMeshBufferAllocator alloc] initWithDevice: _device]];
    MDLMesh *legoMesh = (MDLMesh *)[legoAsset objectAtIndex: 0];
    _vertexBuffer = [[[mtkMesh vertexBuffers] objectAtIndex: 0] buffer];
    _legoMesh = [[MTKMesh alloc] initWithMesh: legoMesh device: _device error: &err];
    
    MTLRenderPipelineDescriptor *pipelineDesc = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineDesc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    pipelineDesc.sampleCount = _view.sampleCount;
    pipelineDesc.colorAttachments[0].blendingEnabled = YES;
    pipelineDesc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
    pipelineDesc.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    pipelineDesc.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
    pipelineDesc.stencilAttachmentPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
    pipelineDesc.vertexFunction = [_library newFunctionWithName: @"vert"];
    pipelineDesc.fragmentFunction = [_library newFunctionWithName: @"frag"];
    pipelineDesc.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO([mtkMesh vertexDescriptor]);
    _pipelineState = [_device newRenderPipelineStateWithDescriptor: pipelineDesc error: &err];
    
    pipelineDesc = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineDesc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    pipelineDesc.sampleCount = _view.sampleCount;
    pipelineDesc.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
    pipelineDesc.stencilAttachmentPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
    pipelineDesc.vertexFunction = [_library newFunctionWithName: @"vert"];
    pipelineDesc.fragmentFunction = [_library newFunctionWithName: @"frag"];
    MTLVertexDescriptor *vertexDesc = MTKMetalVertexDescriptorFromModelIO([legoMesh vertexDescriptor]);
    vertexDesc.layouts[0].stepRate = 1;
    vertexDesc.layouts[0].stepFunction = MTLVertexStepFunctionPerVertex;
    pipelineDesc.vertexDescriptor = vertexDesc;
    _pipelineState2 = [_device newRenderPipelineStateWithDescriptor: pipelineDesc error: &err];
    
    MTLDepthStencilDescriptor *depthDesc = [[MTLDepthStencilDescriptor alloc] init];
    [depthDesc setDepthCompareFunction: MTLCompareFunctionLess];
    depthDesc.depthWriteEnabled = YES;
    _depthState = [_device newDepthStencilStateWithDescriptor: depthDesc];
    
    uniform.modelview = matrix_identity_float4x4;
    uniform.projection = matrix_identity_float4x4;
    _uniformBuffer = [_device newBufferWithLength: sizeof uniform * 3 options: 0];
    [self _reshapeWithSize: _view.drawableSize];
}

- (void)_initView {
    _view.preferredFramesPerSecond = 60;
    _view.device = _device;
    _view.delegate = self;
    _view.depthStencilPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
    _view.sampleCount = 4;
}

- (void)drawInMTKView:(MTKView *)view {
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    
    uniform.modelview = matrix_multiply(matrix_from_translation(0.0f, 0.0f, 5.0f), matrix_from_rotation(_rot, 0.0f, 1.0f, 1.0f));
    //uniform.modelview = matrix_from_rotation(_rot, 0.0f, 1.0f, 1.0f);
    memcpy([_uniformBuffer contents] + _currentThread * sizeof uniform, &uniform, sizeof uniform);
    
    id<MTLCommandBuffer> buffer = [_queue commandBuffer];

    _renderPassDesc = _view.currentRenderPassDescriptor;
    _renderPassDesc.colorAttachments[0].clearColor = MTLClearColorMake(0.8f, 0.1f, 0.0f, 1.0f);
    _renderPassDesc.depthAttachment.loadAction = MTLLoadActionClear;
    _renderPassDesc.depthAttachment.clearDepth = 1.0f;
    _renderPassDesc.depthAttachment.storeAction = MTLStoreActionStore;
    
    MTKMesh* mesh = _view.mode == 1 ? _mtkMesh : _legoMesh;
    MTKMeshBuffer *meshBuffer = _view.mode == 1 ? _mtkMesh.vertexBuffers[0] : _legoMesh.vertexBuffers[0];
    
    id<MTLRenderCommandEncoder> encoder = [buffer renderCommandEncoderWithDescriptor: _renderPassDesc];
    [encoder setLabel: @"Encoder1"];
    [encoder setRenderPipelineState: _view.mode == 1 ? _pipelineState : _pipelineState2];
    [encoder setDepthStencilState: _depthState];
    [encoder setVertexBuffer: meshBuffer.buffer
                      offset: meshBuffer.offset
                     atIndex: 0];
    [encoder setVertexBuffer: _uniformBuffer offset: sizeof(uniform_t) * _currentThread atIndex: 1];
    
    for(NSInteger i = 0; i < mesh.submeshes.count; i++) {
        MTKSubmesh *submesh = mesh.submeshes[i];
        [encoder drawIndexedPrimitives:submesh.primitiveType
                            indexCount:submesh.indexCount
                             indexType:submesh.indexType
                           indexBuffer:submesh.indexBuffer.buffer
                     indexBufferOffset:submesh.indexBuffer.offset];
    }

    [encoder endEncoding];
    
    [buffer addCompletedHandler: ^(id<MTLCommandBuffer> buffer) {
        dispatch_semaphore_signal(semaphore);
    }];
    [buffer presentDrawable: _view.currentDrawable];
    [buffer commit];
    
    if(!_view.showsRenderTexture)
        _rot = _rot + 0.02f;
    if(_rot > 6.283185f)
        _rot -= 6.283185f;
    _currentThread = (_currentThread + 1) % 3;
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    [self _reshapeWithSize: size];
}

- (void)_reshapeWithSize: (CGSize)size {
    float aspect = size.width / size.height;
    uniform.projection = matrix_from_perspective_fov_aspectLH(65.0f * (M_PI / 180.0f), aspect, 3.0f, 10.0f);
    //uniform.projection = matrix_ortho(-2.0f * aspect, 2.0f * aspect, -2.0f, 2.0f, -2.0f, 2.0f);
    memcpy([_uniformBuffer contents] + _currentThread * sizeof uniform, &uniform, sizeof uniform);
}

static matrix_float4x4 matrix_ortho(float left, float right, float bottom, float top, float near, float far) {
    matrix_float4x4 matrix;
    matrix.columns[0] = vector4(2 / (right - left), 0.0f, 0.0f, 0.0f);
    matrix.columns[1] = vector4(0.0f, 2 / (top - bottom), 0.0f, 0.0f);
    matrix.columns[2] = vector4(0.0f, 0.0f, 1 / (far - near), 0.0f);
    matrix.columns[3] = vector4(-(right + left) / (right - left),
                                -(top + bottom) / (top - bottom),
                                -(near) / (far - near), 1.0f);
    return matrix;
}

static matrix_float4x4 matrix_from_perspective_fov_aspectLH(const float fovY, const float aspect, const float nearZ, const float farZ)
{
    float yscale = 1.0f / tanf(fovY * 0.5f); // 1 / tan == cot
    float xscale = yscale / aspect;
    float q = farZ / (farZ - nearZ);
    
    matrix_float4x4 m = {
        .columns[0] = { xscale, 0.0f, 0.0f, 0.0f },
        .columns[1] = { 0.0f, yscale, 0.0f, 0.0f },
        .columns[2] = { 0.0f, 0.0f, q, 1.0f },
        .columns[3] = { 0.0f, 0.0f, q * -nearZ, 0.0f }
    };
    
    return m;
}

static matrix_float4x4 matrix_from_translation(float x, float y, float z)
{
    matrix_float4x4 m = matrix_identity_float4x4;
    m.columns[3] = (vector_float4) { x, y, z, 1.0 };
    return m;
}

static matrix_float4x4 matrix_from_rotation(float radians, float x, float y, float z)
{
    vector_float3 v = vector_normalize(((vector_float3){x, y, z}));
    float cos = cosf(radians);
    float cosp = 1.0f - cos;
    float sin = sinf(radians);
    
    matrix_float4x4 m = {
        .columns[0] = {
            cos + cosp * v.x * v.x,
            cosp * v.x * v.y + v.z * sin,
            cosp * v.x * v.z - v.y * sin,
            0.0f,
        },
        
        .columns[1] = {
            cosp * v.x * v.y - v.z * sin,
            cos + cosp * v.y * v.y,
            cosp * v.y * v.z + v.x * sin,
            0.0f,
        },
        
        .columns[2] = {
            cosp * v.x * v.z + v.y * sin,
            cosp * v.y * v.z - v.x * sin,
            cos + cosp * v.z * v.z,
            0.0f,
        },
        
        .columns[3] = { 0.0f, 0.0f, 0.0f, 1.0f
        }
    };
    return m;
}

@end
