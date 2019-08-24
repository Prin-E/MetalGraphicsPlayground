//
//  MGPMesh.m
//  MetalTextureLOD
//
//  Created by 이현우 on 04/05/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import "MGPMesh.h"
#import "../Utility/MGPCommonVertices.h"
#import "../../Shaders/SharedStructures.h"
#import "MGPBoundingVolume.h"

@implementation MGPSubmesh {
    MTKSubmesh *_metalKitSubmesh;
    NSMutableArray *_textures;
}

@synthesize metalKitSubmesh = _metalKitSubmesh;
@synthesize textures = _textures;

- (instancetype)initWithModelIOMesh: (MDLMesh *)mdlMesh
                     modelIOSubmesh: (MDLSubmesh *)mdlSubmesh
                    metalKitSubmesh: (MTKSubmesh *)mtkSubmesh
                      textureLoader: (MGPTextureLoader *)textureLoader
                        textureDict: (NSMutableDictionary *)textureDict
                              error: (NSError **)error {
    self = [super init];
    if(self) {
        _metalKitSubmesh = mtkSubmesh;
        _textures = [[NSMutableArray alloc] initWithCapacity: tex_total];
        
        MDLMaterialSemantic meterialSemantics[] = {
            MDLMaterialSemanticBaseColor,
            MDLMaterialSemanticTangentSpaceNormal,
            MDLMaterialSemanticRoughness,
            MDLMaterialSemanticMetallic,
            MDLMaterialSemanticAmbientOcclusion,
            MDLMaterialSemanticAnisotropic
        };
        
        for(NSInteger i = 0; i < tex_total; i++) {
            id<MTLTexture> texture = [MGPSubmesh createMetalTextureFromMaterial: mdlSubmesh.material
                                                        modelIOMaterialSemantic: meterialSemantics[i]
                                                                  textureLoader: textureLoader
                                                                    textureDict: textureDict];
            if(texture != nil) {
                [_textures addObject: texture];
            }
            else {
                [_textures addObject: NSNull.null];
            }
        }
        
        [self makeBoundingVolumeWithModelIOMesh:mdlMesh
                                 modelIOSubmesh:mdlSubmesh];
    }
    return self;
}

- (void)makeBoundingVolumeWithModelIOMesh: (MDLMesh *)mdlMesh
                           modelIOSubmesh: (MDLSubmesh *)mdlSubmesh {
    MDLVertexAttributeData *attributeData = [mdlMesh vertexAttributeDataForAttributeNamed: MDLVertexAttributePosition];
    
    // index buffer
    size_t indexSize = mdlSubmesh.indexType / 8;
    MDLMeshBufferMap *indexBufferMap = mdlSubmesh.indexBuffer.map;
    void *indexBufferBytes = indexBufferMap.bytes;
    
    // attribute buffer
    void *posBytes = attributeData.dataStart;
    size_t posStride = attributeData.stride;
    size_t posSize = attributeData.format & 0xF;
    if(attributeData.format & MDLVertexFormatFloatBits)
        posSize = posSize * sizeof(float);
    else {
        NSLog(@"Couldn't parse position attribute because it's not float type.");
        return;
    }
    
    // min/max
    simd_float3 min = simd_make_float3(1e10f, 1e10f, 1e10f);
    simd_float3 max = simd_make_float3(-1e10f, -1e10f, -1e10f);
    
    // iterate over indices
    for(NSUInteger i = 0, cnt = mdlSubmesh.indexCount; i < cnt; i++) {
        size_t index = 0;
        if(indexSize == 1)
            index = *((uint8_t *)indexBufferBytes + i);
        else if(indexSize == 2)
            index = *((uint16_t *)indexBufferBytes + i);
        else if(indexSize == 4)
            index = *((uint32_t *)indexBufferBytes + i);
        
        float pos[4] = {};
        memcpy(pos, posBytes + (posStride * index), posSize);
        min = simd_make_float3(MIN(pos[0], min.x), MIN(pos[1], min.y), MIN(pos[2], min.z));
        max = simd_make_float3(MAX(pos[0], max.x), MAX(pos[1], max.y), MAX(pos[2], max.z));
    }
    
    // calculate center point and radius
    simd_float3 center = (min+max)*0.5;
    float radius = simd_length(max-center);
    
    // make bounding sphere
    // TODO: applying bounding box...
    MGPBoundingSphere *sphere = [MGPBoundingSphere new];
    sphere.radius = radius;
    sphere.position = center;
    _volume = sphere;
}

+ (nonnull id<MTLTexture>) createMetalTextureFromMaterial:(nonnull MDLMaterial *)material
                                  modelIOMaterialSemantic:(MDLMaterialSemantic)materialSemantic
                                            textureLoader:(nonnull MGPTextureLoader *)textureLoader
                                              textureDict:(NSMutableDictionary *)textureDict;
{
    id<MTLTexture> texture;
    
    NSArray<MDLMaterialProperty *> *propertiesWithSemantic =
    [material propertiesWithSemantic:materialSemantic];
    
    for (MDLMaterialProperty *property in propertiesWithSemantic)
    {
        if(property.type == MDLMaterialPropertyTypeString ||
           property.type == MDLMaterialPropertyTypeURL)
        {
            NSURL *url = property.URLValue;
            NSMutableString *URLString = nil;
            if(property.type == MDLMaterialPropertyTypeURL ||
               [url checkResourceIsReachableAndReturnError: nil]) {
                URLString = [[NSMutableString alloc] initWithString:[url absoluteString]];
            } else {
                URLString = [[NSMutableString alloc] initWithString:@"file://"];
                [URLString appendString:property.stringValue];
            }
            
            NSURL *textureURL = [NSURL URLWithString:URLString];
            NSString *textureName = [URLString lastPathComponent];
            NSError *error = nil;
            
            // Find a texture in the pool
            texture = [textureDict objectForKey: textureName];
            
            // If we found a texture in the pool...
            if(texture) {
                // ...return it
                return texture;
            }
            
            // Attempt to load the texture from the file system
            texture = [textureLoader newTextureFromURL: textureURL
                                                 usage: MTLTextureUsageShaderRead
                                           storageMode: MTLStorageModePrivate
                                                 error: &error];
            
            // If we found a texture using the string as a file path name...
            if(texture)
            {
                // save a texture in the pool
                textureDict[texture.label] = texture;
                // ...return it
                return texture;
            }
            
            // If we did not find a texture by interpreting the URL as a path, we'll interpret
            // string as an asset catalog name and attempt to load it with
            //  -[MTKTextureLoader newTextureWithName:scaleFactor:bundle:options::error:]
            texture = [textureLoader newTextureWithName:property.stringValue
                                                  usage:MTLTextureUsageShaderRead
                                            storageMode:MTLStorageModePrivate
                                                  error:&error];
            
            // If we found a texture with the string in our asset catalog...
            if(texture) {
                // save a texture in the pool
                textureDict[texture.label] = texture;
                // ...return it
                return texture;
            }
            
            if(error) {
                NSLog(@"%@", error);
            }
            
            // If did not find the texture in by interpreting it as a file path or as an asset name
            // in our asset catalog, something went wrong (Perhaps the file was missing or
            // misnamed in the asset catalog, model/material file, or file system)
            
            // Depending on how the Metal render pipeline use with this submesh is implemented,
            // this condition can be handled more gracefully.  The app could load a dummy texture
            // that will look okay when set with the pipeline or ensure that  that the pipelines
            // rendering this submesh does not require a material with this property.
            
            [NSException raise:@"Texture data for material property not found"
                        format:@"Requested material property semantic: %lu string: %@",
             materialSemantic, property.stringValue];
        }
    }
    
    /*
    [NSException raise:@"No appropriate material property from which to create texture"
                format:@"Requested material property semantic: %lu", materialSemantic];
    */
    // If we're here, this model doesn't have any textures
    return nil;
}

@end

@implementation MGPMesh {
    MTKMesh *_metalKitMesh;
    NSMutableArray *_submeshes;
    NSMutableDictionary<NSString*, id<MTLTexture>> *_textureDict;
}

@synthesize metalKitMesh = _metalKitMesh;
@synthesize submeshes = _submeshes;

- (instancetype)initWithModelIOMesh: (MDLMesh *)mdlMesh
            modelIOVertexDescriptor: (nonnull MDLVertexDescriptor *)descriptor
                      textureLoader: (MGPTextureLoader *)textureLoader
                             device: (id<MTLDevice>)device
                   calculateNormals: (BOOL)calculateNormals
                              error: (NSError **)error {
    self = [super init];
    if(self) {
        if(calculateNormals || ![mdlMesh vertexAttributeDataForAttributeNamed: MDLVertexAttributeNormal]) {
            [mdlMesh addNormalsWithAttributeNamed:MDLVertexAttributeNormal
                                  creaseThreshold:0.2];
        }
        
        if([mdlMesh vertexAttributeDataForAttributeNamed: MDLVertexAttributeTextureCoordinate]) {
            [mdlMesh addTangentBasisForTextureCoordinateAttributeNamed: MDLVertexAttributeTextureCoordinate
                                                  normalAttributeNamed: MDLVertexAttributeNormal
                                                 tangentAttributeNamed: MDLVertexAttributeTangent];
        }
        mdlMesh.vertexDescriptor = descriptor;
        
        MTKMesh *mtkMesh = [[MTKMesh alloc] initWithMesh: mdlMesh
                                                  device: device
                                                   error: error];
        
        _metalKitMesh = mtkMesh;
        
        // init submeshes
        _submeshes = [[NSMutableArray alloc] initWithCapacity: _metalKitMesh.submeshes.count];
        
        // local texture pool
        _textureDict = [NSMutableDictionary new];
        
        for(NSInteger i = 0; i < _metalKitMesh.submeshes.count; i++) {
            MGPSubmesh *submesh = [[MGPSubmesh alloc] initWithModelIOMesh: mdlMesh
                                                           modelIOSubmesh: mdlMesh.submeshes[i]
                                                          metalKitSubmesh: mtkMesh.submeshes[i]
                                                            textureLoader: textureLoader
                                                              textureDict: _textureDict
                                                                    error: error];
            [_submeshes addObject: submesh];
        }
    }
    return self;
}

+ (NSArray<MGPMesh*>*)loadMeshesFromURL: (NSURL *)url
                modelIOVertexDescriptor: (nonnull MDLVertexDescriptor *)descriptor
                                 device: (id<MTLDevice>)device
                       calculateNormals: (BOOL)calculateNormals
                                  error: (NSError **)error {
    MTKMeshBufferAllocator *allocator = [[MTKMeshBufferAllocator alloc] initWithDevice: device];
    
    MDLAsset *asset = [[MDLAsset alloc] initWithURL: url
                                   vertexDescriptor: descriptor
                                    bufferAllocator: allocator];
    
    NSMutableArray<MGPMesh *> *list = [NSMutableArray new];
    
    
    if(asset != nil) {
        for(MDLObject *object in asset) {
            NSArray<MGPMesh *> *meshes = [MGPMesh loadMeshesFromModelIOObject: object
                                                      modelIOVertexDescriptor: descriptor
                                                                       device: device
                                                             calculateNormals: calculateNormals
                                                                        error: error];
            [list addObjectsFromArray: meshes];
        }
    }
    
    return list;
}

+ (NSArray<MGPMesh*>*)loadMeshesFromModelIOObject: (MDLObject *)object
                          modelIOVertexDescriptor: (nonnull MDLVertexDescriptor *)descriptor
                                           device: (id<MTLDevice>)device
                                 calculateNormals: (BOOL)calculateNormals
                                            error: (NSError **)error {
    NSMutableArray<MGPMesh*> *list = [NSMutableArray new];
    
    if([object isKindOfClass: MDLMesh.class]) {
        MDLMesh *mdlMesh = (MDLMesh *)object;
        MGPTextureLoader *textureLoader = [[MGPTextureLoader alloc] initWithDevice: device];
        
        MGPMesh *mesh = [[MGPMesh alloc] initWithModelIOMesh: mdlMesh
                                     modelIOVertexDescriptor: descriptor
                                               textureLoader: textureLoader
                                                      device: device
                                            calculateNormals: calculateNormals
                                                       error: error];
        
        [list addObject: mesh];
    }
    
    for(MDLObject *child in object.children) {
        NSArray *childMeshes = [MGPMesh loadMeshesFromModelIOObject: child
                                            modelIOVertexDescriptor: descriptor
                                                             device: device
                                                   calculateNormals: calculateNormals
                                                              error: error];
        [list addObjectsFromArray: childMeshes];
    }
    
    return list;
}

+ (id<MTLBuffer>)createQuadVerticesBuffer: (id<MTLDevice>)device {
    // 0x100 = 256
    NSUInteger bufferLength = (sizeof(QuadVertices)+0xFF)&(~0xFF);
    id<MTLBuffer> buffer = [device newBufferWithLength: bufferLength
                                               options: MTLResourceStorageModeManaged];
    memcpy(buffer.contents, QuadVertices, sizeof(QuadVertices));
    [buffer didModifyRange: NSMakeRange(0, sizeof(QuadVertices))];
    return buffer;
}

+ (id<MTLBuffer>)createSkyboxVerticesBuffer: (id<MTLDevice>)device {
    // 0x100 = 256
    NSUInteger bufferLength = (sizeof(SkyboxVertices)+0xFF)&(~0xFF);
    id<MTLBuffer> buffer = [device newBufferWithLength: bufferLength
                                               options: MTLResourceStorageModeManaged];
    memcpy(buffer.contents, SkyboxVertices, sizeof(SkyboxVertices));
    [buffer didModifyRange: NSMakeRange(0, sizeof(SkyboxVertices))];
    return buffer;
}

@end
