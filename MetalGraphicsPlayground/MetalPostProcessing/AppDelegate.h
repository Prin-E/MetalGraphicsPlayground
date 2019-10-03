//
//  AppDelegate.h
//  MetalPostProcessing
//
//  Created by 이현우 on 22/05/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class MGPView;
@class DeferredRenderer;
@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (weak) IBOutlet MGPView *view;
@property (readonly) DeferredRenderer *renderer;

@end

