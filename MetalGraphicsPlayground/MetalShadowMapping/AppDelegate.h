//
//  AppDelegate.h
//  MetalShadowMapping
//
//  Created by 이현우 on 2015. 12. 6..
//  Copyright © 2015년 Prin_E. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@import Metal;
@import MetalKit;

@interface AppDelegate : NSObject <NSApplicationDelegate, MTKViewDelegate>

@property (weak) IBOutlet MTKView *view;

- (IBAction)setRoughness:(id)sender;
- (IBAction)setMetalic:(id)sender;
@end

