//
//  AppDelegate.m
//  MetalGeometry
//
//  Created by 이현우 on 2015. 11. 8..
//  Copyright © 2015년 Prin_E. All rights reserved.
//

#import "AppDelegate.h"

#define kTextureWidth 128
#define kTextureHeight 128
#define kTextureComp 4

#pragma mark - Geometry
static unsigned char *_pixels;

void swap(int *x, int *y) {
    int t = *x;
    *x = *y;
    *y = t;
}

void write_pixel(int x, int y, int color) {
    char comp[4];
    comp[0] = (color & 0xff000000) >> 24;
    comp[1] = (color & 0x00ff0000) >> 16;
    comp[2] = (color & 0x0000ff00) >> 8;
    comp[3] = color & 0xff;
    int *p = (int *)_pixels;
    p[y * kTextureWidth + x] = *((int *)comp);
}

void draw_line_equation(int x1, int y1, int x2, int y2, int color) {
    float m;
    int x, y;
    if(x1 == x2) {
        // 수직선이면
        if(y1 > y2) swap(&y1, &y2);
        for(y = y1; y <= y2; y++) {
            write_pixel(x1, y, color);
        }
        return;
    }
    // 수직선이 아니라면
    m = (float)(y2 - y1) / (float)(x2 - x1);
    if(-1 < m && m < 1) {
        if(x1 > x2) {
            swap(&x1, &x2);
            swap(&y1, &y2);
        }
        for(x = x1; x <= x2; x++) {
            y = m * (x - x1) + y1 + 0.5;
            write_pixel(x, y, color);
        }
    }
    else {
        if(y1 > y2) {
            swap(&x1, &x2);
            swap(&y1, &y2);
        }
        for(y = y1; y <= y2; y++) {
            x = (y - y1) / m + x1 + 0.5;
            write_pixel(x, y, color);
        }
    }
}

void draw_circle_equation(int xc, int yc, int r, int color) {
    int x, y;
    x = 0;
    y = r;
    while(y >= x) {
        write_pixel(x + xc, y + yc, color);
        write_pixel(y + xc, x + yc, color);
        write_pixel(y + xc, -x + yc, color);
        write_pixel(x + xc, -y + yc, color);
        write_pixel(-x + xc, -y + yc, color);
        write_pixel(-y + xc, -x + yc, color);
        write_pixel(-y + xc, x + yc, color);
        write_pixel(-x + xc, y + yc, color);
        x++;
        y = (int)(sqrt((float)r * r - x * x) + 0.5);
    }
}

#pragma mark - AppDelegate
@interface AppDelegate () {
    id<MTLDevice> _device;
    id<MTLLibrary> _library;
    id<MTLCommandQueue> _queue;
    dispatch_semaphore_t _semaphore;
    
    id<MTLTexture> _texture;
    id<MTLRenderPipelineState> _renderPipelineState;
    id<MTLSamplerState> _sampler;
    id<MTLBuffer> _vertexBuffer;
    id<MTLBuffer> _indexBuffer;
}
@property (weak) IBOutlet NSWindow *window;
@property (weak) IBOutlet MTKView *view;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [self _initMetal];
    
    [self _initView];
    
    [self _init];
    
    [self _prepare];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    free(_pixels);
}

- (void)_initMetal {
    _device = MTLCreateSystemDefaultDevice();
    
    _library = [_device newDefaultLibrary];
    
    _queue = [_device newCommandQueue];
}

- (void)_initView {
    _view.delegate = self;
    _view.device = _device;
    _view.preferredFramesPerSecond = 15;
    _view.depthStencilPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
    _view.sampleCount = 1;
}

- (void)_init {
    _semaphore = dispatch_semaphore_create(3);
    
    MTLTextureDescriptor *textureDesc = [[MTLTextureDescriptor alloc] init];
    textureDesc.textureType = MTLTextureType2D;
    textureDesc.pixelFormat = MTLPixelFormatRGBA8Unorm;
    textureDesc.width = kTextureWidth;
    textureDesc.height = kTextureHeight;
    _texture = [_device newTextureWithDescriptor: textureDesc];
    
    MTLSamplerDescriptor *samplerDesc = [[MTLSamplerDescriptor alloc] init];
    samplerDesc.minFilter = MTLSamplerMinMagFilterNearest;
    samplerDesc.magFilter = MTLSamplerMinMagFilterNearest;
    samplerDesc.sAddressMode = MTLSamplerAddressModeClampToEdge;
    samplerDesc.tAddressMode = MTLSamplerAddressModeClampToEdge;
    
    _sampler = [_device newSamplerStateWithDescriptor: samplerDesc];
    
    float posAndUVs[] = {
        -1.0f, -1.0f, 0.0f, 0.0f, 1.0f,
        -1.0f, 1.0f, 0.0f, 0.0f, 0.0f,
        1.0f, 1.0f, 0.0f, 1.0f, 0.0f,
        1.0f, -1.0f, 0.0f, 1.0f, 1.0f
    };
    
    int indices[] = {
        0, 1, 2, 0, 2, 3
    };
    
    _vertexBuffer = [_device newBufferWithBytes: posAndUVs length: sizeof(posAndUVs) options: MTLResourceStorageModeShared];
    _indexBuffer = [_device newBufferWithBytes: indices length: sizeof(indices) options: MTLResourceStorageModeShared];

    [self mtkView: _view drawableSizeWillChange: _view.drawableSize];
    
    MTLVertexDescriptor *vertexDesc = [[MTLVertexDescriptor alloc] init];
    vertexDesc.attributes[0].format = MTLVertexFormatFloat3;
    vertexDesc.attributes[0].offset = 0;
    vertexDesc.attributes[0].bufferIndex = 0;
    vertexDesc.attributes[1].format = MTLVertexFormatFloat2;
    vertexDesc.attributes[1].offset = sizeof(float) * 3;
    vertexDesc.attributes[1].bufferIndex = 0;
    vertexDesc.layouts[0].stride = sizeof(float) * 5;
    vertexDesc.layouts[0].stepFunction = MTLVertexStepFunctionPerVertex;
    
    // first pipeline
    MTLRenderPipelineDescriptor *pipelineDesc = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineDesc.vertexDescriptor = vertexDesc;
    pipelineDesc.vertexFunction = [_library newFunctionWithName: @"vert"];
    pipelineDesc.fragmentFunction = [_library newFunctionWithName: @"frag"];
    pipelineDesc.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
    pipelineDesc.stencilAttachmentPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
    pipelineDesc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    pipelineDesc.sampleCount = _view.sampleCount;
    _renderPipelineState = [_device newRenderPipelineStateWithDescriptor: pipelineDesc
                                                                   error: nil];
}

- (void)_prepare {
    if(_pixels == nil)
        _pixels = (unsigned char *)malloc(sizeof(char) * kTextureWidth * kTextureHeight * kTextureComp);
    
    static char off = 0;
    for(int i = 0; i < kTextureHeight; i++) {
        for(int j = 0; j < kTextureWidth; j++) {
            NSUInteger offset = i * kTextureWidth * kTextureComp + j * kTextureComp;
            _pixels[offset] = 255;
            _pixels[offset + 1] = 255;
            _pixels[offset + 2] = 255;
            _pixels[offset + 3] = 255;
        }
    }
    off++;
    
    write_pixel(10, 10, 0xffff00ff);
    draw_line_equation(75, 30, 10, 114, 0x0000ffff);
    draw_circle_equation(60, 60, 28, 0xff0000ff);
    
    [_texture replaceRegion: MTLRegionMake2D(0, 0, kTextureWidth, kTextureHeight) mipmapLevel: 0 withBytes: _pixels bytesPerRow: kTextureWidth * kTextureComp];
}

- (void)drawInMTKView:(MTKView *)view {
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    
    id<MTLCommandBuffer> buffer = [_queue commandBuffer];
    buffer.label = @"MyBuffer";

    id<MTLRenderCommandEncoder> encoder = [buffer renderCommandEncoderWithDescriptor: view.currentRenderPassDescriptor];
    encoder.label = @"MyEncoder";
    [encoder setRenderPipelineState: _renderPipelineState];
    [encoder setVertexBuffer: _vertexBuffer offset: 0 atIndex: 0];
    [encoder setFragmentTexture: _texture atIndex: 0];
    [encoder setFragmentSamplerState: _sampler atIndex: 0];
    [encoder drawIndexedPrimitives: MTLPrimitiveTypeTriangle
                        indexCount: 6
                         indexType: MTLIndexTypeUInt32
                       indexBuffer:_indexBuffer indexBufferOffset: 0];
    [encoder endEncoding];
    
    [buffer addCompletedHandler: ^(id<MTLCommandBuffer> buffer) {
        dispatch_semaphore_signal(self->_semaphore);
    }];
    
    [buffer presentDrawable: _view.currentDrawable];
    [buffer commit];
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
}


@end