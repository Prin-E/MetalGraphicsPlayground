//
//  ViewController.h
//  MetalInstancing
//
//  Created by 이현우 on 2017. 7. 6..
//  Copyright © 2017년 Prin_E. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@import Metal;
@import MetalKit;
@import ModelIO;

@interface ViewController : NSViewController <MTKViewDelegate>

@property (weak) IBOutlet MTKView *mtkView;

@end

