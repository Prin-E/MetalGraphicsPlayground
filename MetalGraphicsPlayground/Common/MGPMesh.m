//
//  MGPMesh.m
//  MetalTextureLOD
//
//  Created by 이현우 on 04/05/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import "MGPMesh.h"
#import "MGPCommonVertices.h"
#import "Shaders/SharedStructures.h"

@implementation MGPSubmesh {
    MTKSubmesh *_metalKitSubmesh;
    NSMutableArray *_textures;
}

@synthesize metalKitSubmesh = _metalKitSubmesh;
@synthesize textures = _textures;

- (instancetype)initWithModelIOSubmesh: (MDLSubmesh *)mdlSubmesh
                       metalKitSubmesh: (MTKSubmesh *)mtkSubmesh
                         textureLoader: (MTKTextureLoader *)textureLoader
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
                                                          metalKitTextureLoader: textureLoader];
            if(texture != nil) {
                [_textures addObject: texture];
            }
            else {
                [_textures addObject: NSNull.null];
            }
        }
    }
    return self;
}

+ (nonnull id<MTLTexture>) createMetalTextureFromMaterial:(nonnull MDLMaterial *)material
                                  modelIOMaterialSemantic:(MDLMaterialSemantic)materialSemantic
                                    metalKitTextureLoader:(nonnull MTKTextureLoader *)textureLoader
{
    id<MTLTexture> texture;
    
    NSArray<MDLMaterialProperty *> *propertiesWithSemantic =
    [material propertiesWithSemantic:materialSemantic];
    
    for (MDLMaterialProperty *property in propertiesWithSemantic)
    {
        if(property.type == MDLMaterialPropertyTypeString ||
           property.type == MDLMaterialPropertyTypeURL)
        {
            // Load our textures with shader read using private storage
            NSDictionary *textureLoaderOptions =
            @{
              MTKTextureLoaderOptionTextureUsage       : @(MTLTextureUsageShaderRead),
              MTKTextureLoaderOptionTextureStorageMode : @(MTLStorageModePrivate),
              };
            
            // First will interpret the string as a file path and attempt to load it with
            //    -[MTKTextureLoader newTextureWithContentsOfURL:options:error:]
            
            NSURL *url = property.URLValue;
            NSMutableString *URLString = nil;
            if(property.type == MDLMaterialPropertyTypeURL) {
                URLString = [[NSMutableString alloc] initWithString:[url absoluteString]];
            } else {
                URLString = [[NSMutableString alloc] initWithString:@"file://"];
                [URLString appendString:property.stringValue];
            }
            
            NSURL *textureURL = [NSURL URLWithString:URLString];
            
            // Attempt to load the texture from the file system
            texture = [textureLoader newTextureWithContentsOfURL:textureURL
                                                         options:textureLoaderOptions
                                                           error:nil];
            
            // If we found a texture using the string as a file path name...
            if(texture)
            {
                // ...return it
                return texture;
            }
            
            // If we did not find a texture by interpreting the URL as a path, we'll interpret
            // string as an asset catalog name and attempt to load it with
            //  -[MTKTextureLoader newTextureWithName:scaleFactor:bundle:options::error:]
            
            texture = [textureLoader newTextureWithName:property.stringValue
                                            scaleFactor:1.0
                                                 bundle:nil
                                                options:textureLoaderOptions
                                                  error:nil];
            
            // If we found a texture with the string in our asset catalog...
            if(texture) {
                // ...return it
                return texture;
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
}

@synthesize metalKitMesh = _metalKitMesh;
@synthesize submeshes = _submeshes;

- (instancetype)initWithModelIOMesh: (MDLMesh *)mdlMesh
            modelIOVertexDescriptor: (nonnull MDLVertexDescriptor *)descriptor
                      textureLoader: (MTKTextureLoader *)textureLoader
                             device: (id<MTLDevice>)device
                   calculateNormals: (BOOL)calculateNormals
                              error: (NSError **)error {
    self = [super init];
    if(self) {
        if(calculateNormals) {
            [mdlMesh addNormalsWithAttributeNamed:MDLVertexAttributeNormal
                                  creaseThreshold:0.2];
        }
        [mdlMesh addTangentBasisForTextureCoordinateAttributeNamed: MDLVertexAttributeTextureCoordinate
                                              normalAttributeNamed: MDLVertexAttributeNormal
                                             tangentAttributeNamed: MDLVertexAttributeTangent];
        [mdlMesh addTangentBasisForTextureCoordinateAttributeNamed: MDLVertexAttributeTextureCoordinate
                                             tangentAttributeNamed: MDLVertexAttributeTangent
                                           bitangentAttributeNamed: MDLVertexAttributeBitangent];
        
        mdlMesh.vertexDescriptor = descriptor;
        
        MTKMesh *mtkMesh = [[MTKMesh alloc] initWithMesh: mdlMesh
                                                  device: device
                                                   error: error];
        
        _metalKitMesh = mtkMesh;
        
        // init submeshes
        _submeshes = [[NSMutableArray alloc] initWithCapacity: _metalKitMesh.submeshes.count];
        
        for(NSInteger i = 0; i < _metalKitMesh.submeshes.count; i++) {
            MGPSubmesh *submesh = [[MGPSubmesh alloc] initWithModelIOSubmesh: mdlMesh.submeshes[i]
                                                             metalKitSubmesh: mtkMesh.submeshes[i]
                                                               textureLoader: textureLoader
                                                                       error: error];
            [_submeshes addObject: submesh];
        }
    }
    return self;
}

+ (NSArray<MGPMesh*>*)loadMeshesFromURL: (NSURL *)url
                modelIOVertexDescriptor: (nonnull MDLVertexDescriptor *)descriptor
                                 device: (id<MTLDevice>)device
                                  error: (NSError **)error {
    MTKMeshBufferAllocator *allocator = [[MTKMeshBufferAllocator alloc] initWithDevice: device];
    
    MDLAsset *asset = [[MDLAsset alloc] initWithURL: url
                                   vertexDescriptor: nil
                                    bufferAllocator: allocator];
    
    NSMutableArray<MGPMesh *> *list = [NSMutableArray new];
    
    
    if(asset != nil) {
        for(MDLObject *object in asset) {
            NSArray<MGPMesh *> *meshes = [MGPMesh loadMeshesFromModelIOObject: object
                                                      modelIOVertexDescriptor: descriptor
                                                                       device: device
                                                                        error: error];
            [list addObjectsFromArray: meshes];
        }
    }
    
    return list;
}

+ (NSArray<MGPMesh*>*)loadMeshesFromModelIOObject: (MDLObject *)object
                          modelIOVertexDescriptor: (nonnull MDLVertexDescriptor *)descriptor
                                           device: (id<MTLDevice>)device
                                            error: (NSError **)error {
    NSMutableArray<MGPMesh*> *list = [NSMutableArray new];
    
    if([object isKindOfClass: MDLMesh.class]) {
        MDLMesh *mdlMesh = (MDLMesh *)object;
        MTKTextureLoader *textureLoader = [[MTKTextureLoader alloc] initWithDevice: device];
        
        MGPMesh *mesh = [[MGPMesh alloc] initWithModelIOMesh: mdlMesh
                                     modelIOVertexDescriptor: descriptor
                                               textureLoader: textureLoader
                                                      device: device
                                            calculateNormals: YES
                                                       error: error];
        
        [list addObject: mesh];
    }
    
    for(MDLObject *child in object.children) {
        NSArray *childMeshes = [MGPMesh loadMeshesFromModelIOObject: child
                                            modelIOVertexDescriptor: descriptor
                                                             device: device
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
