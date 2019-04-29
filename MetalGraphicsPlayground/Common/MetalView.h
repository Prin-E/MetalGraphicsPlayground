//
//  MetalView.h
//  MetalGraphics
//
//  Created by 이현우 on 2016. 6. 19..
//  Copyright © 2016년 Prin_E. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <MetalKit/MetalKit.h>

@interface MetalView : MTKView

@end

@protocol MetalViewDelegate <MTKViewDelegate>

@optional
- (void)metalView:(MetalView *)view keyDown:(NSEvent *)theEvent;
- (void)metalView:(MetalView *)view mouseDown:(NSEvent *)theEvent;
- (void)metalView:(MetalView *)view mouseDragged:(NSEvent *)theEvent;
- (void)metalView:(MetalView *)view mouseUp:(NSEvent *)theEvent;

@end
