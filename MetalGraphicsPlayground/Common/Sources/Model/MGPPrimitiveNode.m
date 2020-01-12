//
//  MGPPrimitiveNode.m
//  MetalGraphicsPlayground
//
//  Created by 이현우 on 2020/01/12.
//  Copyright © 2020 Prin_E. All rights reserved.
//

#import "MGPRenderer.h"
#import "MGPPrimitiveNode.h"
#import "MGPMesh.h"
#import "MGPMeshComponent.h"
#import "MGPTextureLoader.h"
@import ModelIO;
@import MetalKit;

@implementation MGPPrimitiveNode {
    MDLVertexDescriptor *_vertexDescriptor;
    MTKMeshBufferAllocator *_allocator;
    MGPTextureLoader *_textureLoader;
    id<MTLDevice> _device;
}

- (instancetype)initWithPrimitiveType:(MGPPrimitiveNodeType)primitiveType
                     vertexDescriptor:(MTLVertexDescriptor *)descriptor
                               device:(id<MTLDevice>)device {
    self = [super init];
    if(self) {
        _device = device;
        [self _initVertexDescriptor:descriptor];
        [self _initPrimitiveMeshWithType:primitiveType];
    }
    return self;
}

- (void)_initVertexDescriptor:(MTLVertexDescriptor*)descriptor {
    if(descriptor == nil) {
        // same as G-Buffer's base vertex descriptor
        descriptor = [[MTLVertexDescriptor alloc] init];
        descriptor.attributes[attrib_pos].format = MTLVertexFormatFloat3;
        descriptor.attributes[attrib_pos].offset = 0;
        descriptor.attributes[attrib_pos].bufferIndex = 0;
        descriptor.attributes[attrib_uv].format = MTLVertexFormatFloat2;
        descriptor.attributes[attrib_uv].offset = 12;
        descriptor.attributes[attrib_uv].bufferIndex = 0;
        descriptor.attributes[attrib_normal].format = MTLVertexFormatFloat3;
        descriptor.attributes[attrib_normal].offset = 20;
        descriptor.attributes[attrib_normal].bufferIndex = 0;
        descriptor.attributes[attrib_tangent].format = MTLVertexFormatFloat3;
        descriptor.attributes[attrib_tangent].offset = 32;
        descriptor.attributes[attrib_tangent].bufferIndex = 0;
        descriptor.layouts[0].stride = 44;
        descriptor.layouts[0].stepRate = 1;
        descriptor.layouts[0].stepFunction = MTLStepFunctionPerVertex;
    }
    _vertexDescriptor = MTKModelIOVertexDescriptorFromMetal(descriptor);
    _vertexDescriptor.attributes[attrib_pos].name = MDLVertexAttributePosition;
    _vertexDescriptor.attributes[attrib_uv].name = MDLVertexAttributeTextureCoordinate;
    _vertexDescriptor.attributes[attrib_normal].name = MDLVertexAttributeNormal;
    _vertexDescriptor.attributes[attrib_tangent].name = MDLVertexAttributeTangent;
}

- (void)_initPrimitiveMeshWithType:(MGPPrimitiveNodeType)primitiveType {
    MDLMesh *primitiveMesh = nil;
    _allocator = [[MTKMeshBufferAllocator alloc] initWithDevice:_device];
    _textureLoader = [[MGPTextureLoader alloc] initWithDevice:_device];
    switch(primitiveType) {
        case MGPPrimitiveNodeTypeSphere:
            primitiveMesh = [self _spherePrimitiveMesh];
            break;
        case MGPPrimitiveNodeTypeCube:
            primitiveMesh = [self _cubePrimitiveMesh];
            break;
        case MGPPrimitiveNodeTypePlane:
            primitiveMesh = [self _planePrimitiveMesh];
            break;
    }
    NSError *error = nil;
    MGPMesh *mesh = [[MGPMesh alloc] initWithModelIOMesh:primitiveMesh
                                 modelIOVertexDescriptor:_vertexDescriptor
                                           textureLoader:_textureLoader
                                                  device:_device
                                        calculateNormals:NO
                                                   error:&error];
    if(error) {
        NSLog(@"%@", error);
    }
    
    MGPMeshComponent *meshComp = [[MGPMeshComponent alloc] initWithMesh:mesh];
    [self addComponent:meshComp];
}

#pragma mark - Primitive meshes
- (MDLMesh *)_spherePrimitiveMesh {
    static MDLMesh *mesh = nil;
    if(!mesh) {
        mesh = [MDLMesh newEllipsoidWithRadii:simd_make_float3(0.5,0.5,0.5)
                               radialSegments:16
                             verticalSegments:16
                                 geometryType:MDLGeometryTypeTriangles
                                inwardNormals:NO
                                   hemisphere:NO
                                    allocator:_allocator];
        }
    return mesh;
}

- (MDLMesh *)_cubePrimitiveMesh {
    static MDLMesh *mesh = nil;
    if(!mesh) {
        mesh = [MDLMesh newBoxWithDimensions:simd_make_float3(1.0,1.0,1.0)
                                    segments:simd_make_uint3(1,1,1)
                                geometryType:MDLGeometryTypeTriangles
                               inwardNormals:NO
                                   allocator:_allocator];
    }
    return mesh;
}

- (MDLMesh *)_planePrimitiveMesh {
    static MDLMesh *mesh = nil;
    if(!mesh) {
        mesh = [MDLMesh newPlaneWithDimensions:simd_make_float2(1.0,1.0)
                                      segments:simd_make_uint2(1,1)
                                  geometryType:MDLGeometryTypeTriangles
                                     allocator:_allocator];
    }
    return mesh;
}

- (material_t)material {
    material_t material = [(MGPMeshComponent *)[self componentOfType:MGPMeshComponent.class] material];
    return material;
}

- (void)setMaterial:(material_t)material {
    [(MGPMeshComponent *)[self componentOfType:MGPMeshComponent.class] setMaterial:material];
}

@end
