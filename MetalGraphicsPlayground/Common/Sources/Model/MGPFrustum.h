//
//  MGPFrustum.h
//  MetalGraphicsPlayground
//
//  Created by 이현우 on 2019/08/13.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class MGPPlane;
@class MGPCamera;
@interface MGPFrustum : NSObject

// world-space 6 planes (near, far, left, right, bottom, top), normal inside
@property (readonly) NSArray<MGPPlane*> *planes;

- (instancetype)initWithCamera: (MGPCamera *)camera;
- (void)setPlanesForCamera: (MGPCamera *)camera;

@end

NS_ASSUME_NONNULL_END
