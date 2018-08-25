//
//  MyView.h
//  MetalGraphics
//
//  Created by 이현우 on 2015. 9. 13..
//  Copyright © 2015년 Prin_E. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@import MetalKit;

@interface MyView : MTKView

@property (nonatomic, readonly) BOOL showsRenderTexture;
@property (nonatomic, readonly) NSUInteger mode;

@end
