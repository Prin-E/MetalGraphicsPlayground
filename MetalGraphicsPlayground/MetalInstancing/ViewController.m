//
//  ViewController.m
//  MetalInstancing
//
//  Created by 이현우 on 2017. 7. 6..
//  Copyright © 2017년 Prin_E. All rights reserved.
//

#import "ViewController.h"
#import "SharedStructures.h"

@implementation ViewController {
    id<MTLDevice> _device;
    id<MTLLibrary> _library;
    id<MTLCommandQueue> _queue;
    id<MTLBuffer> _instanceBuffer;
    
    dispatch_semaphore_t _semaphore;
    
    MTKMesh *_sphereMesh;
    id<MTLRenderPipelineState> _spherePipeline;
}

- (void)awakeFromNib {
    _device = MTLCreateSystemDefaultDevice();
    _library = [_device newDefaultLibrary];
    _queue = [_device newCommandQueue];
    
    _semaphore = dispatch_semaphore_create(3);
    
    _mtkView.device = _device;
    _mtkView.sampleCount = 1;
    _mtkView.clearColor = MTLClearColorMake(0, 0, 1, 1);
    _mtkView.delegate = self;
    
    MDLMesh *mdlMesh = [[MDLMesh alloc] initSphereWithExtent: vector3(0.5f,0.5f,0.5f)
                                                    segments: vector2(24u, 24u)
                                               inwardNormals: NO
                                                geometryType: MDLGeometryTypeTriangles
                                                   allocator: [[MTKMeshBufferAllocator alloc] initWithDevice: _device]];
    
    _sphereMesh = [[MTKMesh alloc] initWithMesh: mdlMesh
                                         device: _device
                                          error: nil];
    
    MTLRenderPipelineDescriptor *pipelineDesc = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineDesc.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(_sphereMesh.vertexDescriptor);
    pipelineDesc.vertexFunction = [_library newFunctionWithName: @"vert"];
    pipelineDesc.fragmentFunction = [_library newFunctionWithName: @"frag"];
    pipelineDesc.colorAttachments[0].pixelFormat = _mtkView.colorPixelFormat;
    pipelineDesc.colorAttachments[0].blendingEnabled = NO;
    pipelineDesc.depthAttachmentPixelFormat = _mtkView.depthStencilPixelFormat;
    _spherePipeline = [_device newRenderPipelineStateWithDescriptor: pipelineDesc
                                                              error: nil];
    
    _instanceBuffer = [_device newBufferWithLength: sizeof(instance_buffer_t) options: MTLResourceStorageModeManaged];
    
    instance_buffer_t *ptr = (instance_buffer_t *)_instanceBuffer.contents;
    for(int i = 0; i < 40; i++) {
        for(int j = 0; j < 40; j++) {
            ptr->pos[i*40+j] = vector3(-2.0f + 0.1f * i, -2.0f + 0.1f * j, 0.0f);
            ptr->scale[i*40+j] = vector3(0.1f, 0.1f, 0.1f);
        }
    }
    [_instanceBuffer didModifyRange: NSMakeRange(0, sizeof(instance_buffer_t))];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // Do any additional setup after loading the view.
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    
}

- (void)drawInMTKView:(MTKView *)view {
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    
    id<MTLCommandBuffer> buffer = [_queue commandBuffer];
    MTLRenderPassDescriptor *renderPass = _mtkView.currentRenderPassDescriptor;
    //renderPass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 1, 1);
    id<MTLRenderCommandEncoder> encoder = [buffer renderCommandEncoderWithDescriptor: renderPass];
    [encoder setRenderPipelineState: _spherePipeline];
    [encoder setVertexBuffer: _sphereMesh.vertexBuffers[0].buffer offset: 0 atIndex: 0];
    [encoder setVertexBuffer: _instanceBuffer offset: 0 atIndex: 1];
    for (MTKSubmesh *submesh in _sphereMesh.submeshes) {
        /*
        [encoder drawIndexedPrimitives: MTLPrimitiveTypeTriangle
                            indexCount: submesh.indexCount
                             indexType: submesh.indexType
                           indexBuffer: submesh.indexBuffer.buffer
                     indexBufferOffset: submesh.indexBuffer.offset];
         */
        [encoder drawIndexedPrimitives: MTLPrimitiveTypeTriangle
                            indexCount: submesh.indexCount
                             indexType: submesh.indexType
                           indexBuffer: submesh.indexBuffer.buffer
                     indexBufferOffset: submesh.indexBuffer.offset
                         instanceCount: 1600];
    }
    
    [encoder endEncoding];
    [buffer addCompletedHandler: ^(id<MTLCommandBuffer> buffer) {
        dispatch_semaphore_signal(_semaphore);
    }];
    [buffer presentDrawable: _mtkView.currentDrawable];
    [buffer commit];
}

@end
