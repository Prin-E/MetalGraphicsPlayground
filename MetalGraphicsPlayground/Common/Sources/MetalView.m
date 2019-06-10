//
//  MetalView.m
//  MetalGraphics
//
//  Created by 이현우 on 2016. 6. 19..
//  Copyright © 2016년 Prin_E. All rights reserved.
//

#import "MetalView.h"

@implementation MetalView

- (instancetype)initWithFrame:(CGRect)frameRect device:(id<MTLDevice>)device {
    self = [super initWithFrame:frameRect device:device];
    if(self) {
        NSLog(@"device=%@", device);
    }
    return self;
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (BOOL)becomeFirstResponder {
    return YES;
}

- (void)keyDown:(NSEvent *)event {
    if(self.delegate != nil && [self.delegate respondsToSelector: @selector(metalView:keyDown:)])
        [(id<MetalViewDelegate>)self.delegate metalView: self keyDown: event];
}

- (void)mouseDown:(NSEvent *)event {
    if(self.delegate != nil && [self.delegate respondsToSelector: @selector(metalView:mouseDown:)])
        [(id<MetalViewDelegate>)self.delegate metalView: self mouseDown: event];
}

- (void)mouseDragged:(NSEvent *)event {
    if(self.delegate != nil && [self.delegate respondsToSelector: @selector(metalView:mouseDragged:)])
        [(id<MetalViewDelegate>)self.delegate metalView: self mouseDragged: event];
}

- (void)mouseUp:(NSEvent *)event {
    if(self.delegate != nil && [self.delegate respondsToSelector: @selector(metalView:mouseUp:)])
        [(id<MetalViewDelegate>)self.delegate metalView: self mouseUp: event];
}

@end
