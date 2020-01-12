//
//  MGPPrimitiveNode.h
//  MetalGraphicsPlayground
//
//  Created by 이현우 on 2020/01/12.
//  Copyright © 2020 Prin_E. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MGPSceneNode.h"
#import "SharedStructures.h"
@import Metal;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, MGPPrimitiveNodeType) {
    MGPPrimitiveNodeTypeSphere,
    MGPPrimitiveNodeTypeCube,
    MGPPrimitiveNodeTypePlane
};

@interface MGPPrimitiveNode : MGPSceneNode

- (instancetype)initWithPrimitiveType:(MGPPrimitiveNodeType)primitiveType
                     vertexDescriptor:(MTLVertexDescriptor *)descriptor
                               device:(id<MTLDevice>)device;

@property (nonatomic) material_t material;

@end

NS_ASSUME_NONNULL_END
