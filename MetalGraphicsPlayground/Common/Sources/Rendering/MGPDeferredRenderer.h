//
//  MGPDeferredRenderer.h
//  MetalGraphicsPlayground
//
//  Created by 이현우 on 2019/10/09.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MGPSceneRenderer.h"

NS_ASSUME_NONNULL_BEGIN

@class MGPGBuffer;

// Tile deferred renderer
@interface MGPDeferredRenderer : MGPSceneRenderer

// G-buffer
@property (readonly) MGPGBuffer *gBuffer;
@property (nonatomic) NSUInteger gBufferIndex;

// Render options
@property (readwrite) BOOL usesAnisotropy;

@end

NS_ASSUME_NONNULL_END
