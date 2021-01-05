//
//  AppDelegate.m
//  MetalEnvironmentMapping
//
//  Created by 이현우 on 2016. 12. 20..
//  Copyright © 2016년 Prin_E. All rights reserved.
//

#import "AppDelegate.h"
#import "MetalMath.h"
#import "SharedStructures.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@property (weak) IBOutlet MTKView *view;
@end

@implementation AppDelegate {
    id<MTLDevice> _device;
    id<MTLLibrary> _library;
    id<MTLCommandQueue> _queue;
    
    MTKMesh *_cubeMesh;
    MTKMesh *_sphereMesh;
    MTKMesh *_boxMesh;
    MTKMesh *_planeXZMesh;
    MTKMesh *_modelMesh;
    
    MTLRenderPassDescriptor *_renderPassDesc;
    id<MTLRenderPipelineState> _cubePipeline;
    id<MTLRenderPipelineState> _modelPipeline;
    id<MTLRenderPipelineState> _irradianceCubePipeline;
    id<MTLRenderPipelineState> _PMREMPipeline;
    id<MTLRenderPipelineState> _LUTPipeline;
    id<MTLDepthStencilState> _depthState;
    
    id<MTLBuffer> _uniformBuffer;
    id<MTLBuffer> _irradianceUniformBuffer;
    id<MTLBuffer> _cubemapRenderTargetInfoBuffer;
    id<MTLBuffer> _appInfoBuffer;
    NSMutableArray<id<MTLTexture>> *_cubeMaps;
    NSMutableArray<id<MTLTexture>> *_irradianceMaps;
    NSMutableArray<id<MTLTexture>> *_PMREMs;
    id<MTLTexture> _LUT;
    id<MTLTexture> _depthStencilTex;
    
    id<MTLTexture> _currentCubeMap, _currentIrradianceMap, _currentPMREM;
    
    dispatch_semaphore_t _semaphore;
    
    uniform_t uniform;
    NSUInteger _currentThread;
    
    float _time;
    float _rot;
    float _mouseRotX, _mouseRotZ;
    float _xPos,_zPos;
    BOOL _rotate;
    
    NSDate *_prevDate;
}

id<MTLTexture> ddd;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    _rotate = YES;
    _zPos = -0.25f;
    _albedo = vector4(1.0f, 1.0f, 1.0f, 1.0f);
    _prevDate = [NSDate date];
    _window.delegate = self;
    
    
    
    [self _initMetal];
    [self _initView];
    [self _initAssets];
    [self _reshape];
    
    
    
    const int cnt = 256;
    float arr[cnt][cnt][2];
    for(int i = 0; i < cnt; i++) {
        for(int j = 0; j < cnt; j++) {
            vector_float2 c = IntegrateBRDF((float)i/(float)cnt, (float)j/(float)cnt);
            arr[i][j][0] = c.x;
            arr[i][j][1] = c.y;
        }
    }
    
    MTLTextureDescriptor *desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatRG32Float
                                                                                   width: cnt
                                                                                  height: cnt
                                                                               mipmapped: NO];
    id<MTLTexture> tex = [_device newTextureWithDescriptor: desc];
    [tex setLabel: @"DummyTex"];
    [tex replaceRegion: MTLRegionMake2D(0, 0, cnt, cnt)
           mipmapLevel: 0
             withBytes: arr
           bytesPerRow: 8*cnt];
    ddd =tex;
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

- (void)_initMetal {
    _device = MTLCreateSystemDefaultDevice();
    _library = [_device newDefaultLibrary];
    _queue = [_device newCommandQueue];
}

- (void)_initView {
    _view.device = _device;
    _view.preferredFramesPerSecond = 60;
    _view.delegate = self;
    _view.depthStencilPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
}

- (void)_initAssets {
    _uniformBuffer = [_device newBufferWithLength: sizeof(uniform_t) * 3
                                          options: 0];
    _irradianceUniformBuffer = [_device newBufferWithLength: sizeof(irradiance_uniform_t) * 6
                                                    options: 0];
    _cubemapRenderTargetInfoBuffer = [_device newBufferWithLength: sizeof(cubemap_rendertarget_info_t) * 36
                                                          options: 0];
    _appInfoBuffer = [_device newBufferWithLength: sizeof(app_info_t)
                                          options: 0];
    
    MTKMeshBufferAllocator *allocator = [[MTKMeshBufferAllocator alloc] initWithDevice: _device];
    /*
    MDLMesh *mesh = [MDLMesh newBoxWithDimensions: vector3(1.0f,1.0f,1.0f)
                                         segments: vector3(2u,2u,2u)
                                     geometryType: MDLGeometryTypeTriangles
                                    inwardNormals: YES
                                        allocator: allocator];
    */
    
    MDLMesh *mesh = [MDLMesh newEllipsoidWithRadii: vector3(1.0f,1.0f,1.0f)
                                    radialSegments: 4
                                  verticalSegments: 4
                                      geometryType: MDLGeometryTypeTriangles
                                     inwardNormals: YES
                                        hemisphere: NO
                                         allocator: allocator];
    
    _cubeMesh = [[MTKMesh alloc] initWithMesh: mesh device: _device error: nil];
    
    // Sphere
    mesh = [MDLMesh newEllipsoidWithRadii: vector3(1.0f,1.0f,1.0f)
                                    radialSegments: 4
                                  verticalSegments: 4
                                      geometryType: MDLGeometryTypeTriangles
                                     inwardNormals: YES
                                        hemisphere: NO
                                         allocator: allocator];
    _sphereMesh = [[MTKMesh alloc] initWithMesh: mesh device: _device error: nil];
    
    // Box
    mesh = [MDLMesh newBoxWithDimensions: vector3(2.0f,2.0f,2.0f)
                                         segments: vector3(1u,1u,1u)
                                     geometryType: MDLGeometryTypeTriangles
                                    inwardNormals: YES
                                        allocator: allocator];
    _boxMesh = [[MTKMesh alloc] initWithMesh: mesh device: _device error: nil];
    
    // Plane (X-Z)
    mesh = [MDLMesh newPlaneWithDimensions: vector2(2.0f, 2.0f)
                                  segments: vector2(1u,1u)
                              geometryType: MDLGeometryTypeTriangles
                                 allocator: allocator];
    _planeXZMesh = [[MTKMesh alloc] initWithMesh: mesh device: _device error: nil];
    
    /*
    mesh = [MDLMesh newEllipsoidWithRadii: vector3(0.05f,0.05f,0.05f)
                           radialSegments: 64
                         verticalSegments: 64
                             geometryType: MDLGeometryTypeTriangles
                            inwardNormals: NO
                               hemisphere: NO
                                allocator: allocator];
    */
    
    MDLAsset *bunny = [[MDLAsset alloc] initWithURL: [[NSBundle mainBundle] URLForResource: @"bun_zipper" withExtension: @"obj"] vertexDescriptor: nil bufferAllocator: [[MTKMeshBufferAllocator alloc] initWithDevice: _device]];
    mesh = (MDLMesh *)[bunny objectAtIndex: 0];
    _modelMesh = [[MTKMesh alloc] initWithMesh: mesh device: _device error: nil];
    
    MTLRenderPipelineDescriptor *pd = [[MTLRenderPipelineDescriptor alloc] init];
    
    // cubemap
    pd.vertexFunction = [_library newFunctionWithName: @"vert"];
    pd.fragmentFunction = [_library newFunctionWithName: @"frag"];
    pd.sampleCount = 1;
    pd.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
    pd.stencilAttachmentPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
    pd.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    pd.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(_cubeMesh.vertexDescriptor);
    _cubePipeline = [_device newRenderPipelineStateWithDescriptor: pd error: nil];
    
    // irradiance
    pd.vertexFunction = [_library newFunctionWithName: @"irradiance_vert"];
    pd.fragmentFunction = [_library newFunctionWithName: @"irradiance_frag"];
    pd.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(_sphereMesh.vertexDescriptor);
    _irradianceCubePipeline = [_device newRenderPipelineStateWithDescriptor: pd
                                                                      error: nil];
    
    // PMREM
    pd.vertexFunction = [_library newFunctionWithName: @"pmrem_vert"];
    pd.fragmentFunction = [_library newFunctionWithName: @"pmrem_frag"];
    pd.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(_boxMesh.vertexDescriptor);
    _PMREMPipeline = [_device newRenderPipelineStateWithDescriptor: pd
                                                             error: nil];
    
    // LUT
    pd.vertexFunction = [_library newFunctionWithName: @"lut_vert"];
    pd.fragmentFunction = [_library newFunctionWithName: @"lut_frag"];
    pd.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(_planeXZMesh.vertexDescriptor);
    pd.depthAttachmentPixelFormat = MTLPixelFormatInvalid;
    pd.stencilAttachmentPixelFormat = MTLPixelFormatInvalid;
    pd.colorAttachments[0].pixelFormat = MTLPixelFormatRG32Float;
    _LUTPipeline = [_device newRenderPipelineStateWithDescriptor: pd
                                                          error: nil];
    
    // model
    pd.vertexFunction = [_library newFunctionWithName: @"vert"];
    pd.fragmentFunction = [_library newFunctionWithName: @"frag2"];
    pd.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
    pd.stencilAttachmentPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
    pd.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    pd.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(_modelMesh.vertexDescriptor);
    _modelPipeline = [_device newRenderPipelineStateWithDescriptor: pd error: nil];
    
    MTLDepthStencilDescriptor *depthDesc = [[MTLDepthStencilDescriptor alloc] init];
    [depthDesc setDepthCompareFunction: MTLCompareFunctionLess];
    depthDesc.depthWriteEnabled = YES;
    _depthState = [_device newDepthStencilStateWithDescriptor: depthDesc];
    
    MTLTextureDescriptor *depthTexDesc = [MTLTextureDescriptor textureCubeDescriptorWithPixelFormat: MTLPixelFormatDepth32Float_Stencil8
                                                                                               size: 512
                                                                                          mipmapped: YES];
    depthTexDesc.mipmapLevelCount = 6;
    depthTexDesc.storageMode = MTLStorageModePrivate;
    depthTexDesc.usage = MTLTextureUsageRenderTarget;
    _depthStencilTex = [_device newTextureWithDescriptor: depthTexDesc];
    
    [self _loadCubeMap];
    
    _semaphore = dispatch_semaphore_create(3);
}

- (void)_loadCubeMap {
    _cubeMaps = [NSMutableArray<id<MTLTexture>> new];
    _irradianceMaps = [NSMutableArray<id<MTLTexture>> new];
    _PMREMs = [NSMutableArray<id<MTLTexture>> new];
    
    MTLTextureDescriptor *LUTDesc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatRG32Float
                                                                                       width: 512
                                                                                      height: 512
                                                                                   mipmapped: NO];
    LUTDesc.usage |= MTLTextureUsageRenderTarget;
    _LUT = [_device newTextureWithDescriptor: LUTDesc];
    _LUT.label = @"LUT";
    
    MTLTextureDescriptor *irradianceMapDesc = [MTLTextureDescriptor textureCubeDescriptorWithPixelFormat: MTLPixelFormatBGRA8Unorm
                                                                                               size: 64
                                                                                          mipmapped: NO];
    
    irradianceMapDesc.usage |= MTLTextureUsageRenderTarget;
    
    MTLTextureDescriptor *PMREMDesc = [MTLTextureDescriptor textureCubeDescriptorWithPixelFormat: MTLPixelFormatBGRA8Unorm
                                                                                            size: 512
                                                                                       mipmapped: YES];
    
    PMREMDesc.usage |= MTLTextureUsageRenderTarget;
    PMREMDesc.mipmapLevelCount = 6;
    
    MTLTextureDescriptor *cubeMapDesc = [MTLTextureDescriptor textureCubeDescriptorWithPixelFormat: MTLPixelFormatRGBA8Unorm
                                                                                              size: 2048
                                                                                         mipmapped: NO];
    
    NSArray<NSString*> *dirs = @[@"Yokohama2", @"Yokohama3"];
    NSArray<NSString*> *list = @[@"posx",
                                 @"negx",
                                 @"posy",
                                 @"negy",
                                 @"posz",
                                 @"negz"];
    
    for (NSString *dir in dirs) {
        id<MTLTexture> irradianceMap = [_device newTextureWithDescriptor: irradianceMapDesc];
        irradianceMap.label = [NSString stringWithFormat: @"irradiance - %@", dir];
        [_irradianceMaps addObject: irradianceMap];
        if(_currentIrradianceMap == nil)
            _currentIrradianceMap = irradianceMap;
        
        id<MTLTexture> PMREM = [_device newTextureWithDescriptor: PMREMDesc];
        PMREM.label = [NSString stringWithFormat: @"PMREM - %@", dir];
        [_PMREMs addObject: PMREM];
        if(_currentPMREM == nil)
            _currentPMREM = PMREM;
        
        id<MTLTexture> cubeMap = [_device newTextureWithDescriptor: cubeMapDesc];
        cubeMap.label = [NSString stringWithFormat: @"cubemap - %@", dir];
        [_cubeMaps addObject: cubeMap];
        if (_currentCubeMap == nil)
            _currentCubeMap = cubeMap;
        
        for (NSInteger i = 0; i < list.count; i++) {
            NSString *name = list[i];
            uint8_t *imgBytes = [self dataForImage: name ofDirectory: dir];
            [cubeMap replaceRegion: MTLRegionMake2D(0, 0, 2048, 2048)
                        mipmapLevel: 0
                              slice: i
                          withBytes: imgBytes
                        bytesPerRow: 4 * 2048
                      bytesPerImage: 4 * 2048 * 2048];
            free(imgBytes);
        }
    }
}

- (uint8_t *)dataForImage:(NSString *)imgName ofDirectory: (NSString *)dirName
{
    NSImage *img = [NSImage imageNamed: [NSString stringWithFormat: @"%@/%@", dirName, imgName]];
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

- (void)_reshape {
}

- (void)_drawIrradianceMap {
    matrix_float4x4 lookat[6] = {
        matrix_lookat(vector3(0.0f, 0.0f, 0.0f), vector3(1.0f, 0.0f, 0.0f), vector3(0.0f, 1.0f, 0.0f)),
        matrix_lookat(vector3(0.0f, 0.0f, 0.0f), vector3(-1.0f, 0.0f, 0.0f), vector3(0.0f, 1.0f, 0.0f)),
        matrix_lookat(vector3(0.0f, 0.0f, 0.0f), vector3(0.0f, 1.0f, 0.0f), vector3(0.0f, 0.0f, -1.0f)),
        matrix_lookat(vector3(0.0f, 0.0f, 0.0f), vector3(0.0f, -1.0f, 0.0f), vector3(0.0f, 1.0f, 1.0f)),
        matrix_lookat(vector3(0.0f, 0.0f, 0.0f), vector3(0.0f, 0.0f, 1.0f), vector3(0.0f, 1.0f, 0.0f)),
        matrix_lookat(vector3(0.0f, 0.0f, 0.0f), vector3(0.0f, 0.0f, -1.0f), vector3(0.0f, 1.0f, 0.0f))
    };
    
    MTLRenderPassDescriptor *renderPass = _view.currentRenderPassDescriptor;
    renderPass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1);
    renderPass.colorAttachments[0].texture = _currentIrradianceMap;
    
    id<MTLCommandBuffer> buffer = [_queue commandBuffer];
    id<MTLRenderCommandEncoder> enc = nil;
    
    irradiance_uniform_t irradianceUniform;
    
    for(int i = 0; i < 6; i++) {
        // prepares uniform buffer...
        irradianceUniform.model = matrix_identity_float4x4;
        irradianceUniform.view = lookat[i];
        irradianceUniform.projection = matrix_from_perspective_fov_aspectLH(90.0f * (M_PI / 180.0f), 1.0f, 0.1f, 10.0f);
        memcpy([_irradianceUniformBuffer contents] + i * sizeof irradianceUniform, &irradianceUniform, sizeof irradianceUniform);
    }
    
    for(int j = 0; j < 6; j++) {
        // draw faces...
        renderPass.colorAttachments[0].slice = j;
        enc = [buffer renderCommandEncoderWithDescriptor: renderPass];
        [enc setLabel: @"Draw Irradiance Map"];
        [enc setRenderPipelineState: _irradianceCubePipeline];
        [enc setDepthStencilState: _depthState];
        [enc setVertexBuffer: _sphereMesh.vertexBuffers[0].buffer
                      offset: _sphereMesh.vertexBuffers[0].offset
                     atIndex: 0];
        [enc setVertexBuffer: _irradianceUniformBuffer offset: j * sizeof irradianceUniform atIndex: 1];
        [enc setFragmentBuffer: _irradianceUniformBuffer offset: j * sizeof irradianceUniform atIndex: 1];
        [enc setFragmentTexture: _currentCubeMap atIndex: 0];
        
        for(int i = 0; i < _sphereMesh.submeshes.count; i++) {
            MTKSubmesh *submesh = _sphereMesh.submeshes[i];
            [enc drawIndexedPrimitives: submesh.primitiveType
                            indexCount: submesh.indexCount
                             indexType: submesh.indexType
                           indexBuffer: submesh.indexBuffer.buffer
                     indexBufferOffset: submesh.indexBuffer.offset];
        }
        [enc textureBarrier];
        [enc endEncoding];
    }
    
    [buffer commit];
}

- (void)_drawPMREM {
    matrix_float4x4 lookat[6] = {
        matrix_lookat(vector3(0.0f, 0.0f, 0.0f), vector3(1.0f, 0.0f, 0.0f), vector3(0.0f, 1.0f, 0.0f)),
        matrix_lookat(vector3(0.0f, 0.0f, 0.0f), vector3(-1.0f, 0.0f, 0.0f), vector3(0.0f, 1.0f, 0.0f)),
        matrix_lookat(vector3(0.0f, 0.0f, 0.0f), vector3(0.0f, 1.0f, 0.0f), vector3(0.0f, 0.0f, -1.0f)),
        matrix_lookat(vector3(0.0f, 0.0f, 0.0f), vector3(0.0f, -1.0f, 0.0f), vector3(0.0f, 1.0f, 1.0f)),
        matrix_lookat(vector3(0.0f, 0.0f, 0.0f), vector3(0.0f, 0.0f, 1.0f), vector3(0.0f, 1.0f, 0.0f)),
        matrix_lookat(vector3(0.0f, 0.0f, 0.0f), vector3(0.0f, 0.0f, -1.0f), vector3(0.0f, 1.0f, 0.0f))
    };
    
    MTLRenderPassDescriptor *renderPass = [MTLRenderPassDescriptor renderPassDescriptor];
    renderPass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1);
    renderPass.colorAttachments[0].texture = _currentPMREM;
    renderPass.depthAttachment.texture = _depthStencilTex;
    renderPass.stencilAttachment.texture = _depthStencilTex;
    
    id<MTLCommandBuffer> buffer = [_queue commandBuffer];
    id<MTLRenderCommandEncoder> enc = nil;
    
    irradiance_uniform_t irradianceUniform;
    cubemap_rendertarget_info_t cubemapRenderTargetInfo;
    
    for(int i = 0; i < 6; i++) {
        // prepares uniform buffer...
        irradianceUniform.model = matrix_identity_float4x4;
        irradianceUniform.view = lookat[i];
        irradianceUniform.projection = matrix_from_perspective_fov_aspectLH(90.0f * (M_PI / 180.0f), 1.0f, 0.1f, 10.0f);
        memcpy([_irradianceUniformBuffer contents] + i * sizeof irradianceUniform, &irradianceUniform, sizeof irradianceUniform);
    }
    
    for(int i = 0; i < 6; i++) {
        for(int j = 0; j < 6; j++) {
            // prepares uniform buffer...
            cubemapRenderTargetInfo.cubeFace = i;
            cubemapRenderTargetInfo.mipLevel = j;
            memcpy([_cubemapRenderTargetInfoBuffer contents] + (i*6+j) * sizeof cubemapRenderTargetInfo, &cubemapRenderTargetInfo, sizeof cubemapRenderTargetInfo);
        }
    }
    
    for(int j = 0; j < 6; j++) {
        for(int k = 0; k < 6; k++) {
            // draw faces...
            renderPass.colorAttachments[0].slice = j;
            renderPass.colorAttachments[0].level = k;
            renderPass.depthAttachment.slice = j;
            renderPass.depthAttachment.level = k;
            renderPass.stencilAttachment.slice = j;
            renderPass.stencilAttachment.level = k;
            enc = [buffer renderCommandEncoderWithDescriptor: renderPass];
            [enc setLabel: @"Draw PMREM"];
            [enc setRenderPipelineState: _PMREMPipeline];
            [enc setDepthStencilState: _depthState];
            [enc setVertexBuffer: _boxMesh.vertexBuffers[0].buffer
                          offset: _boxMesh.vertexBuffers[0].offset
                         atIndex: 0];
            [enc setVertexBuffer: _irradianceUniformBuffer offset: j * sizeof irradianceUniform atIndex: 1];
            [enc setFragmentBuffer: _irradianceUniformBuffer offset: j * sizeof irradianceUniform atIndex: 1];
            [enc setFragmentBuffer: _cubemapRenderTargetInfoBuffer offset: (j*6+k) * sizeof cubemapRenderTargetInfo atIndex: 2];
            [enc setFragmentTexture: _currentCubeMap atIndex: 0];
            
            for(int i = 0; i < _boxMesh.submeshes.count; i++) {
                MTKSubmesh *submesh = _boxMesh.submeshes[i];
                [enc drawIndexedPrimitives: submesh.primitiveType
                                indexCount: submesh.indexCount
                                 indexType: submesh.indexType
                               indexBuffer: submesh.indexBuffer.buffer
                         indexBufferOffset: submesh.indexBuffer.offset];
            }
            [enc textureBarrier];
            [enc endEncoding];
        }
    }
    
    [buffer commit];
}

- (void)_drawLUT {
    MTLRenderPassDescriptor *renderPass = [MTLRenderPassDescriptor renderPassDescriptor];
    renderPass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1);
    renderPass.colorAttachments[0].texture = _LUT;
    
    id<MTLCommandBuffer> buffer = [_queue commandBuffer];
    id<MTLRenderCommandEncoder> enc = [buffer renderCommandEncoderWithDescriptor: renderPass];
    [enc setLabel: @"LUT"];
    [enc setRenderPipelineState: _LUTPipeline];
    [enc setVertexBuffer: _planeXZMesh.vertexBuffers[0].buffer
                  offset: _planeXZMesh.vertexBuffers[0].offset
                 atIndex: 0];
    for(int i = 0; i < _planeXZMesh.submeshes.count; i++) {
        MTKSubmesh *submesh = _planeXZMesh.submeshes[i];
        [enc drawIndexedPrimitives: submesh.primitiveType
                        indexCount: submesh.indexCount
                         indexType: submesh.indexType
                       indexBuffer: submesh.indexBuffer.buffer
                 indexBufferOffset: submesh.indexBuffer.offset];
    }
    [enc textureBarrier];
    [enc endEncoding];
    
    [buffer commit];
}

static BOOL _shouldDrawIrradianceMap = YES;
static BOOL _shouldDrawPMREM = YES;
static BOOL _shouldDrawLUT = YES;

- (void)drawInMTKView:(MTKView *)view {
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    
    if(_shouldDrawIrradianceMap)
    {
        [self _drawIrradianceMap];
        _shouldDrawIrradianceMap = NO;
    }
    if(_shouldDrawPMREM)
    {
        [self _drawPMREM];
        _shouldDrawPMREM = NO;
    }
    if(_shouldDrawLUT)
    {
        [self _drawLUT];
        _shouldDrawLUT = NO;
    }
    
    NSDate *date = [NSDate date];
    NSTimeInterval interval = [date timeIntervalSinceDate: _prevDate];
    if(_rotate) {
        _rot += (float)interval * 3.14159 * 0.1f;
        if(_rot >= 6.28f)
            _rot -= 6.28f;
    }
    _time = _time + interval;
    _prevDate = date;
    
    app_info_t appInfo;
    appInfo.time = fmodf(_time, 6.0f);
    appInfo.roughness = _roughness;
    appInfo.metalic = _metalic;
    appInfo.albedo = _albedo;
    memcpy([_appInfoBuffer contents], &appInfo, sizeof appInfo);
    
    matrix_float4x4 rotMat = matrix_from_rotation(_mouseRotZ, 0.0f, 0.0f, 1.0f);
    rotMat = matrix_multiply(rotMat, matrix_from_rotation(_mouseRotX, 1.0f, 0.0f, 0.0f));
    rotMat = matrix_multiply(rotMat, matrix_from_rotation(_rot, 0.0f, 1.0f, 0.0f));
    matrix_float4x4 lookat = matrix_lookat(vector3(_xPos, 0.0f, _zPos), vector3(0.0f, 0.0f, 1.0f), vector3(0.0f, 1.0f, 0.0f));
    uniform.model = rotMat;
    uniform.view = lookat;
    CGSize size = _view.drawableSize;
    float aspect = size.width / size.height;
    uniform.projection = matrix_from_perspective_fov_aspectLH(60.0f * (M_PI / 180.0f), aspect, 0.1f, 10.0f);
    uniform.modelviewInverse = matrix_invert(matrix_multiply(uniform.view, uniform.model));
    memcpy([_uniformBuffer contents] + _currentThread * sizeof uniform, &uniform, sizeof uniform);
    
    id<MTLCommandBuffer> buffer = [_queue commandBuffer];
    id<MTLRenderCommandEncoder> enc = nil;
    
    // Render
    MTLRenderPassDescriptor *renderPass = _view.currentRenderPassDescriptor;
    renderPass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1);
    enc = [buffer renderCommandEncoderWithDescriptor: renderPass];
    [enc setLabel: @"Draw Cubemap"];
    [enc setRenderPipelineState: _cubePipeline];
    [enc setDepthStencilState: _depthState];
    [enc setVertexBuffer: _cubeMesh.vertexBuffers[0].buffer
                  offset: 0
                 atIndex: 0];
    [enc setFragmentTexture: _currentCubeMap atIndex: 0];
    for(int i = 0; i < _cubeMesh.submeshes.count; i++) {
        MTKSubmesh *submesh = _cubeMesh.submeshes[i];
        [enc setVertexBuffer: _uniformBuffer offset: _currentThread * sizeof uniform atIndex: 1];
        [enc drawIndexedPrimitives: submesh.primitiveType
                        indexCount: submesh.indexCount
                         indexType: submesh.indexType
                       indexBuffer: submesh.indexBuffer.buffer
                 indexBufferOffset: 0];
    }
    
    [enc setLabel: @"Draw Model"];
    [enc setRenderPipelineState: _modelPipeline];
    [enc setDepthStencilState: _depthState];
    [enc setVertexBuffer: _modelMesh.vertexBuffers[0].buffer
                  offset: _modelMesh.vertexBuffers[0].offset
                 atIndex: 0];
    [enc setFragmentBuffer: _appInfoBuffer offset: 0 atIndex: 0];
    [enc setFragmentTexture: _currentCubeMap atIndex: 0];
    [enc setFragmentTexture: _currentIrradianceMap atIndex: 1];
    [enc setFragmentTexture: _currentPMREM atIndex: 2];
    [enc setFragmentTexture: _LUT atIndex: 3];
    for(int i = 0; i < _modelMesh.submeshes.count; i++) {
        MTKSubmesh *submesh = _modelMesh.submeshes[i];
        [enc setVertexBuffer: _uniformBuffer offset: _currentThread * sizeof uniform atIndex: 1];
        [enc drawIndexedPrimitives: submesh.primitiveType
                        indexCount: submesh.indexCount
                         indexType: submesh.indexType
                       indexBuffer: submesh.indexBuffer.buffer
                 indexBufferOffset: submesh.indexBuffer.offset];
    }
    
    [enc endEncoding];
    
    [buffer addCompletedHandler: ^(id<MTLCommandBuffer> b) {
        dispatch_semaphore_signal(_semaphore);
    }];
    [buffer presentDrawable: _view.currentDrawable];
    [buffer commit];
    
    _currentThread = (_currentThread + 1) % 3;
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    [self _reshape];
}

/*
- (void)metalView:(MetalView *)view keyDown:(NSEvent *)theEvent {
    if(theEvent.keyCode == 126)
        _zPos += .01f;
    else if(theEvent.keyCode == 125)
        _zPos -= .01f;
    else if(theEvent.keyCode == 123)
        _xPos -= .01f;
    else if(theEvent.keyCode == 124)
        _xPos += .01f;
    else if(theEvent.keyCode == 49)
    _rotate = !_rotate;
    else if(theEvent.keyCode == 18)
    {
        if(_cubeMaps.count > 0) {
            _currentCubeMap = [_cubeMaps objectAtIndex: 0];
            _currentIrradianceMap = [_irradianceMaps objectAtIndex: 0];
            _currentPMREM = [_PMREMs objectAtIndex: 0];
            _shouldDrawIrradianceMap = YES;
            _shouldDrawPMREM = YES;
        }
    }
    else if(theEvent.keyCode == 19)
    {
        if(_cubeMaps.count > 1) {
            _currentCubeMap = [_cubeMaps objectAtIndex: 1];
            _currentIrradianceMap = [_irradianceMaps objectAtIndex: 1];
            _currentPMREM = [_PMREMs objectAtIndex: 1];
            _shouldDrawIrradianceMap = YES;
            _shouldDrawPMREM = YES;
        }
    }
}

- (void)metalView:(MTKView *)view mouseDragged:(NSEvent *)theEvent {
    //CGSize viewSize = _view.drawableSize;
    //float aspect = viewSize.width / viewSize.height;
    
    //_mouseRotZ += theEvent.deltaY / viewSize.height * -90.0f;
    //_mouseRotX += theEvent.deltaX / viewSize.width * 90.0f;
}
*/
  
- (void)windowDidEnterFullScreen:(NSNotification *)notification {
    [self _reshape];
}

- (void)windowDidExitFullScreen:(NSNotification *)notification {
    [self _reshape];
}

- (IBAction)changeRoughness:(id)sender {
    _roughness = [sender floatValue];
}

- (IBAction)changeMetalic:(id)sender {
    _metalic = [sender floatValue];
}

- (IBAction)changeAlbedo:(id)sender {
    NSColorWell *colorWell = sender;
    NSColor *color = colorWell.color;
    _albedo = vector4((float)color.redComponent, (float)color.greenComponent,
                      (float)color.blueComponent, (float)color.alphaComponent);
}

#define saturate(x) fmax(0.0f, fmin(1.0f, (x)))

uint reverse_bits(uint x)
{
    x = (((x & 0xaaaaaaaa) >> 1) | ((x & 0x55555555) << 1));
    x = (((x & 0xcccccccc) >> 2) | ((x & 0x33333333) << 2));
    x = (((x & 0xf0f0f0f0) >> 4) | ((x & 0x0f0f0f0f) << 4));
    x = (((x & 0xff00ff00) >> 8) | ((x & 0x00ff00ff) << 8));
    return((x >> 16) | (x << 16));
}

vector_float2 hammersley(uint i, uint N)
{
    // 2.3283064365386963e-10 = 0.5 / 0x10000000
    float ri = reverse_bits(i) * 2.3283064365386963e-10;
    return vector2((float)i / (float)N, ri);
}

float GGX(float NdotV, float a)
{
    float k = a / 2;
    return NdotV / (NdotV * (1.0f - k) + k);
}

float G_Smith(float a, float nDotV, float nDotL)
{
    return GGX(nDotL, a * a) * GGX(nDotV, a * a);
}

// TEST
vector_float3 ImportanceSampleGGX(vector_float2 Xi, float Roughness, vector_float3 N)
{
    float a = Roughness * Roughness; // DISNEY'S ROUGHNESS [see Burley'12 siggraph]
    
    float Phi = M_PI * 2 * Xi.x;
    float CosTheta = sqrt((1 - Xi.y) / (1 + (a * a - 1) * Xi.y));
    float SinTheta = sqrt(1 - CosTheta * CosTheta);
    
    vector_float3 H;
    H.x = SinTheta * cos(Phi);
    H.y = SinTheta * sin(Phi);
    H.z = CosTheta;
    
    vector_float3 UpVector = fabsf(N.z) < 0.999 ? vector3(0.0f, 0.0f, 1.0f) : vector3(1.0f, 0.0f, 0.0f);
    vector_float3 TangentX = vector_normalize(vector_cross(UpVector, N));
    vector_float3 TangentY = vector_cross(N, TangentX);
    
    // Tangent to world space
    return TangentX * H.x + TangentY * H.y + N * H.z;
}

vector_float2 IntegrateBRDF(float Roughness, float NoV)
{
    vector_float3 V;
    
    V.x = sqrt(1.0f - NoV * NoV);	// Sin
    V.y = 0;
    V.z = NoV;						// Cos
    
    float A = 0;
    float B = 0;
    
    vector_float3 N = vector3(0.0f, 0.0f, 1.0f);
    
    const uint NumSamples = 64;
    
    for (uint i = 0; i < NumSamples; i++)
    {
        vector_float2 Xi = hammersley(i, NumSamples);
        vector_float3 H = ImportanceSampleGGX(Xi, Roughness, N);
        vector_float3 L = 2.0f * vector_dot(V, H) * H - V;
        
        float NoL = saturate(L.z);
        float NoH = saturate(H.z);
        float VoH = saturate(vector_dot(V, H));
        
        if (NoL > 0)
        {
            float G = G_Smith(Roughness, NoV, NoL);
            float G_Vis = G * VoH / fmax(0.00001, NoH * NoV);
            
            float Fc = pow(1 - VoH, 5);
            
            A += (1 - Fc) * G_Vis;
            B += Fc * G_Vis;
        }
    }
    
    A /= (float)NumSamples;
    B /= (float)NumSamples;
    
    return vector2(A, B);
}

@end
