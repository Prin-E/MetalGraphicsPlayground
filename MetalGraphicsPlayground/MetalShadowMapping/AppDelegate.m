//
//  AppDelegate.m
//  MetalShadowMapping
//
//  Created by 이현우 on 2015. 12. 6..
//  Copyright © 2015년 Prin_E. All rights reserved.
//

#import "AppDelegate.h"
#import "SharedStructures.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate {
    id<MTLDevice> _device;
    id<MTLLibrary> _library;
    id<MTLCommandQueue> _queue;
    
    id<MTLRenderPipelineState> _pipeline;
    id<MTLRenderPipelineState> _planePipeline;
    id<MTLRenderPipelineState> _shadowPipeline;
    id<MTLRenderPipelineState> _shadowPreviewPipeline;
    id<MTLDepthStencilState> _depth;
    
    MTLRenderPassDescriptor *_renderPass;
    
    dispatch_semaphore_t _semaphore;
    NSInteger _currentThread;
    
    id<MTLBuffer> _planeBuffer;
    id<MTLBuffer> _planeIndexBuffer;
    id<MTLBuffer> _uniformBuffer;
    id<MTLBuffer> _shadowPreviewBuffer;
    uniform_t uniform;
    
    // Assets
    MTKMesh *_mesh;
    
    // Shadow Map
    id<MTLTexture> _shadowMap;
    MTLRenderPassDescriptor *_shadowMapPassDesc;
    
    // Cube Map
    id<MTLTexture> _cubeMap;
    
    float _r;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [self _initMetal];
    [self _initAssets];
    [self _initMTKView];
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

- (void)_initMTKView {
    _view.preferredFramesPerSecond = 60;
    _view.device = _device;
    _view.delegate = self;
    _view.depthStencilPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
    _view.sampleCount = 1;
}

- (void)_initAssets {
    NSError *error = nil;
    
    float planeVertex[] = {
        -120.0f, -10.0f, -120.0f, 0.0f, 1.0f, 0.0f, 0.0f, 0.0f,
        -120.0f, -10.0f, 120.0f, 0.0f, 1.0f, 0.0f, 0.0f, 1.0f,
        120.0f, -10.0f, 120.0f, 0.0f, 1.0f, 0.0f, 1.0f, 1.0f,
        120.0f, -10.0f, -120.0f, 0.0f, 1.0f, 0.0f, 1.0f, 0.0f,
        -120.0f, 110.0f, -120.0f, 0.0f, 1.0f, 0.0f, 0.0f, 0.0f,
        -120.0f, 110.0f, 120.0f, 0.0f, 1.0f, 0.0f, 0.0f, 1.0f,
        120.0f, 110.0f, 120.0f, 0.0f, 1.0f, 0.0f, 1.0f, 1.0f,
        120.0f, 110.0f, -120.0f, 0.0f, 1.0f, 0.0f, 1.0f, 0.0f
    };
    int planeIndices[] = {
        0,4,5,0,5,1,    // -x
        2,7,6,2,3,7,    // +x
        0,1,2,0,2,3,    // -y
        4,6,5,4,7,6,    // +y
        0,3,7,0,7,4,    // -z
        1,6,2,1,5,6     // +z
    };
    
    _planeBuffer = [_device newBufferWithBytes: planeVertex length: sizeof(planeVertex) options: 0];
    _planeIndexBuffer = [_device newBufferWithBytes: planeIndices length: sizeof(planeIndices) options: 0];
    
    float shadowPreviewVertex[] = {
        -1.0f, 0.5f, 0.0f, 0.0f, 0.0f,
        -1.0f, 1.0f, 0.0f, 0.0f, 1.0f,
        -0.5f, 1.0f, 0.0f, 1.0f, 1.0f,
        -1.0f, 0.5f, 0.0f, 0.0f, 0.0f,
        -0.5f, 1.0f, 0.0f, 1.0f, 1.0f,
        -0.5f, 0.5f, 0.0f, 1.0f, 0.0f
    };
    
    _shadowPreviewBuffer = [_device newBufferWithBytes: shadowPreviewVertex length: sizeof(shadowPreviewVertex) options: 0];
    
    MTLVertexDescriptor *planeVertexDesc = [[MTLVertexDescriptor alloc] init];
    planeVertexDesc.layouts[0].stepFunction = MTLVertexStepFunctionPerVertex;
    planeVertexDesc.layouts[0].stride = 32;
    planeVertexDesc.attributes[0].offset = 0;
    planeVertexDesc.attributes[0].bufferIndex = 0;
    planeVertexDesc.attributes[0].format = MTLVertexFormatFloat3;
    planeVertexDesc.attributes[1].offset = 12;
    planeVertexDesc.attributes[1].bufferIndex = 0;
    planeVertexDesc.attributes[1].format = MTLVertexFormatFloat3;
    planeVertexDesc.attributes[2].offset = 24;
    planeVertexDesc.attributes[2].bufferIndex = 0;
    planeVertexDesc.attributes[2].format = MTLVertexFormatFloat2;
    
    MTLVertexDescriptor *previewVertexDesc = [[MTLVertexDescriptor alloc] init];
    previewVertexDesc.layouts[0].stepFunction = MTLVertexStepFunctionPerVertex;
    previewVertexDesc.layouts[0].stride = 20;
    previewVertexDesc.attributes[0].offset = 0;
    previewVertexDesc.attributes[0].bufferIndex = 0;
    previewVertexDesc.attributes[0].format = MTLVertexFormatFloat3;
    previewVertexDesc.attributes[1].offset = 12;
    previewVertexDesc.attributes[1].bufferIndex = 0;
    previewVertexDesc.attributes[1].format = MTLVertexFormatFloat2;
    
    MTLRenderPipelineDescriptor *pipelineDesc = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineDesc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    pipelineDesc.colorAttachments[0].blendingEnabled = NO;
    pipelineDesc.vertexFunction = [_library newFunctionWithName: @"vert"];
    pipelineDesc.fragmentFunction = [_library newFunctionWithName: @"frag"];
    pipelineDesc.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
    pipelineDesc.stencilAttachmentPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
    pipelineDesc.vertexDescriptor = planeVertexDesc;
    _planePipeline = [_device newRenderPipelineStateWithDescriptor: pipelineDesc error: &error];
    if(error != nil) { NSLog(@"%@", error); error = nil; }
    
    pipelineDesc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    pipelineDesc.vertexFunction = [_library newFunctionWithName: @"shadow_preview_vert"];
    pipelineDesc.fragmentFunction = [_library newFunctionWithName: @"shadow_preview_frag"];
    pipelineDesc.vertexDescriptor = previewVertexDesc;
    _shadowPreviewPipeline = [_device newRenderPipelineStateWithDescriptor: pipelineDesc error: &error];
    if(error != nil) { NSLog(@"%@", error); error = nil; }

    uniform.roughness = 0.5f;
    uniform.metalic = 0.5f;
    _uniformBuffer = [_device newBufferWithLength: sizeof(uniform_t) * 3 options: 0];
    
    MDLAsset *asset = [[MDLAsset alloc] initWithURL: [[NSBundle mainBundle] URLForResource: @"lego"
                                                                             withExtension: @"obj"]
                                   vertexDescriptor: nil
                                    bufferAllocator: [[MTKMeshBufferAllocator alloc] initWithDevice: _device]];
    MDLMesh *mdlMesh = (MDLMesh *)[asset objectAtIndex: 0];
    _mesh = [[MTKMesh alloc] initWithMesh: mdlMesh device: _device error: nil];
    
    pipelineDesc = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineDesc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    pipelineDesc.colorAttachments[0].blendingEnabled = NO;
    pipelineDesc.vertexFunction = [_library newFunctionWithName: @"vert"];
    pipelineDesc.fragmentFunction = [_library newFunctionWithName: @"frag"];
    pipelineDesc.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
    pipelineDesc.stencilAttachmentPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
    pipelineDesc.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(_mesh.vertexDescriptor);
    _pipeline = [_device newRenderPipelineStateWithDescriptor: pipelineDesc
                                                        error: &error];
    if(error != nil) { NSLog(@"%@", error); error = nil; }
    
    pipelineDesc.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float;
    pipelineDesc.stencilAttachmentPixelFormat = MTLPixelFormatInvalid;
    pipelineDesc.colorAttachments[0].pixelFormat = MTLPixelFormatInvalid;
    pipelineDesc.vertexFunction = [_library newFunctionWithName: @"shadow_vert"];
    pipelineDesc.fragmentFunction = nil;
    _shadowPipeline = [_device newRenderPipelineStateWithDescriptor: pipelineDesc error: &error];
    if(error != nil) { NSLog(@"%@", error); error = nil; }
    
    MTLDepthStencilDescriptor *depthDesc = [[MTLDepthStencilDescriptor alloc] init];
    [depthDesc setDepthCompareFunction: MTLCompareFunctionLess];
    depthDesc.depthWriteEnabled = YES;
    _depth = [_device newDepthStencilStateWithDescriptor: depthDesc];
    
    // Shadow Map
    MTLTextureDescriptor *shadowMapDesc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatDepth32Float
                                                                                             width: 1024
                                                                                            height: 1024
                                                                                         mipmapped: NO];
    
    shadowMapDesc.usage = MTLTextureUsagePixelFormatView | MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget;
    shadowMapDesc.resourceOptions = MTLResourceStorageModePrivate;
    _shadowMap = [_device newTextureWithDescriptor: shadowMapDesc];
    
    _shadowMapPassDesc = [[MTLRenderPassDescriptor alloc] init];
    _shadowMapPassDesc.depthAttachment.loadAction = MTLLoadActionClear;
    _shadowMapPassDesc.depthAttachment.storeAction = MTLStoreActionStore;
    _shadowMapPassDesc.depthAttachment.texture = _shadowMap;

    // Cube Map
    MTLTextureDescriptor *cubeMapDesc = [MTLTextureDescriptor textureCubeDescriptorWithPixelFormat: MTLPixelFormatRGBA8Unorm
                                                                                              size: 2048
                                                                                         mipmapped: NO];
    _cubeMap = [_device newTextureWithDescriptor: cubeMapDesc];
    [self _loadCubeMap];
    
    // Update uniform
    [self _reshapeWithSize: _view.drawableSize];
}

- (void)_loadCubeMap {
    NSArray<NSString*> *list = @[@"posx",@"negx",@"posy",@"negy",@"posz",@"negz"];
    for (NSInteger i = 0; i < list.count; i++) {
        NSString *name = list[i];
        uint8_t *imgBytes = [self dataForImage: name];
        [_cubeMap replaceRegion: MTLRegionMake2D(0, 0, 2048, 2048)
                    mipmapLevel: 0
                          slice: i
                      withBytes: imgBytes
                    bytesPerRow: 4 * 2048
                  bytesPerImage: 4 * 2048 * 2048];
        free(imgBytes);
    }
}

- (uint8_t *)dataForImage:(NSString *)name
{
    NSImage *img = [NSImage imageNamed: name];
    NSBitmapImageRep *imgRep = (NSBitmapImageRep *)[[img representations] objectAtIndex: 0];
    CGImageRef imageRef = [imgRep CGImage];
    
    // Create a suitable bitmap context for extracting the bits of the image
    const NSUInteger width = CGImageGetWidth(imageRef);
    const NSUInteger height = CGImageGetHeight(imageRef);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    uint8_t *rawData = (uint8_t *)calloc(height * width * 4, sizeof(uint8_t));
    const NSUInteger bytesPerPixel = 4;
    const NSUInteger bytesPerRow = bytesPerPixel * width;
    const NSUInteger bitsPerComponent = 8;
    CGContextRef context = CGBitmapContextCreate(rawData, width, height,
                                                 bitsPerComponent, bytesPerRow, colorSpace,
                                                 kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
    CGContextRelease(context);
    
    return rawData;
}

- (void)drawInMTKView:(MTKView *)view {
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    
    float aspect = view.drawableSize.width / view.drawableSize.height;
    uniform.light = matrix_multiply(matrix_from_rotation(-0.6f, 1.0f, 0.0f, 1.0f), matrix_from_rotation(-_r, 0.0f, 1.0f, 0.0f));
    uniform.light = matrix_multiply(matrix_from_translation(0, -5, 16), uniform.light);
    uniform.light = matrix_multiply(matrix_from_perspective_fov_aspectLH(65.0f * (M_PI / 180.0f), aspect, 5.0f, 100.0f), uniform.light);
    uniform.modelview = matrix_multiply(matrix_from_translation(0, -8, 16), matrix_multiply(matrix_from_rotation(-0.388f, 1.0f, 0.0f, 0.0f),matrix_from_rotation(_r, 0.0f, 1.0f, 0.0f)));
    memcpy([_uniformBuffer contents] + _currentThread * sizeof uniform, &uniform, sizeof uniform);
    
    // test
    vector_float4 pos = vector4(0.0f, 8.0f, -16.0f, 1.0f);
    pos = matrix_multiply(uniform.light,pos);
    
    
    
    
    id<MTLCommandBuffer> commandBuffer = [_queue commandBuffer];
    
    id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor: _shadowMapPassDesc];
    [encoder setLabel: @"Shadow Map"];
    [self _drawModelsInEncoder: encoder gBuffer: YES];
    [encoder endEncoding];
    
    _renderPass = _view.currentRenderPassDescriptor;
    _renderPass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1);
    _renderPass.colorAttachments[0].loadAction = MTLLoadActionClear;
    _renderPass.depthAttachment.loadAction = MTLLoadActionClear;
    
    encoder = [commandBuffer renderCommandEncoderWithDescriptor: _renderPass];
    [encoder setLabel: @"Lego And Plane, Shadow Preview"];
    [encoder setFragmentTexture: _shadowMap atIndex: 0];
    [encoder setFragmentTexture: _cubeMap atIndex: 1];
    [encoder setFragmentBuffer: _uniformBuffer offset: 0 atIndex: 1];
    [self _drawModelsInEncoder: encoder gBuffer: NO];
    [encoder setRenderPipelineState: _shadowPreviewPipeline];
    [encoder setVertexBuffer: _shadowPreviewBuffer offset: 0 atIndex: 0];
    [encoder drawPrimitives: MTLPrimitiveTypeTriangle vertexStart: 0 vertexCount: 6];
    [encoder endEncoding];
    
    [commandBuffer addCompletedHandler: ^(id<MTLCommandBuffer> buffer) {
        dispatch_semaphore_signal(_semaphore);
    }];
    [commandBuffer presentDrawable: _view.currentDrawable];
    [commandBuffer commit];
    
    _currentThread = (_currentThread + 1) % 3;
    _r += 0.005f;
    if(_r > 6.28f) _r -= 6.28f;
}

- (void)_drawModelsInEncoder: (id<MTLRenderCommandEncoder>)encoder gBuffer: (BOOL)gBuffer {
    [encoder setVertexBuffer: _uniformBuffer offset: sizeof(uniform_t) * _currentThread atIndex: 1];
    
    if(!gBuffer) {
        [encoder pushDebugGroup: @"Plane"];
        [encoder setRenderPipelineState: _planePipeline];
        [encoder setVertexBuffer: _planeBuffer offset: 0 atIndex: 0];
        [encoder drawIndexedPrimitives: MTLPrimitiveTypeTriangle
                            indexCount: 36
                             indexType: MTLIndexTypeUInt32
                           indexBuffer: _planeIndexBuffer
                     indexBufferOffset: 0];
        [encoder popDebugGroup];
    }
    
    [encoder pushDebugGroup: @"Mesh"];
    [encoder setRenderPipelineState: gBuffer ? _shadowPipeline : _pipeline];
    [encoder setDepthStencilState: _depth];
    [encoder setVertexBuffer: _mesh.vertexBuffers[0].buffer
                      offset: _mesh.vertexBuffers[0].offset
                     atIndex: 0];
    [encoder setFragmentBuffer: _uniformBuffer offset: 0 atIndex: 1];
    // draw submeshes
    for(int i = 0; i < _mesh.submeshes.count; i++) {
        MTKSubmesh *submesh = _mesh.submeshes[i];
        [encoder drawIndexedPrimitives:submesh.primitiveType
                            indexCount:submesh.indexCount
                             indexType:submesh.indexType
                           indexBuffer:submesh.indexBuffer.buffer
                     indexBufferOffset:submesh.indexBuffer.offset];
    }
    [encoder popDebugGroup];
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    [self _reshapeWithSize: size];
}

- (void)_reshapeWithSize: (CGSize)size {
    float aspect = size.width / size.height;
    uniform.projection = matrix_from_perspective_fov_aspectLH(65.0f * (M_PI / 180.0f), aspect, 0.1f, 250.0f);
    memcpy([_uniformBuffer contents] + _currentThread * sizeof uniform, &uniform, sizeof uniform);
}

- (IBAction)setRoughness:(id)sender {
    uniform.roughness = [sender floatValue];
}

- (IBAction)setMetalic:(id)sender {
    uniform.metalic = [sender floatValue];
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
