//
//  DeferredRenderer.h
//  MetalDeferred
//
//  Created by 이현우 on 03/05/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "../Common/Sources/Rendering/MGPDeferredRenderer.h"
#import "../Common/Sources/View/MGPView.h"

NS_ASSUME_NONNULL_BEGIN

@interface DeferredRenderer : MGPDeferredRenderer <MGPViewDelegate>

@property (readwrite) float roughness, metalic, anisotropy;
@property (readwrite) unsigned int numLights;
@property (readwrite) BOOL showsTestObjects;

@end

NS_ASSUME_NONNULL_END
