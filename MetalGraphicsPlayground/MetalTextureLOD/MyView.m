//
//  MyView.m
//  MetalGraphics
//
//  Created by 이현우 on 2015. 9. 13..
//  Copyright © 2015년 Prin_E. All rights reserved.
//

#import "MyView.h"

@implementation MyView

- (id)initWithFrame:(CGRect)frameRect {
    return [super initWithFrame: frameRect];
}

- (void)awakeFromNib {
    _mode = 1;
}

- (void)keyDown: (NSEvent *)event {
    if([event keyCode] == 49)
        _showsRenderTexture = !_showsRenderTexture;
    
    if([event keyCode] >= 18 && [event keyCode] <= 21)
        _mode = [event keyCode] - 17;
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (BOOL)becomeFirstResponder {
    return YES;
}

@end
