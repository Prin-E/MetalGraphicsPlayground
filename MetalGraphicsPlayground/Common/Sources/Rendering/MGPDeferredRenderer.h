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

// Tile deferred renderer
@interface MGPDeferredRenderer : MGPSceneRenderer

@property (nonatomic) NSUInteger gBufferIndex;

@end

NS_ASSUME_NONNULL_END
