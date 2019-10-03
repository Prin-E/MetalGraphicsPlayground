//
//  AppDelegate.m
//  MetalPostProcessing
//
//  Created by 이현우 on 22/05/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import "AppDelegate.h"
#import "DeferredRenderer.h"

@interface AppDelegate () {
    DeferredRenderer *renderer;
    NSTimer *timer;
}

@property (weak) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSTextField *CPUTimeText, *GPUTimeText;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [self willChangeValueForKey: @"renderer"];
    renderer = [[DeferredRenderer alloc] init];
    _view.renderer = renderer;
    [self didChangeValueForKey: @"renderer"];

    // Timer
    timer = [NSTimer scheduledTimerWithTimeInterval: 0.5
                                            repeats: YES block:^(NSTimer * _Nonnull timer) {
        self->_CPUTimeText.stringValue = [NSString stringWithFormat: @"CPU : %.2fms", self->renderer.CPUTime * 1000];
        self->_GPUTimeText.stringValue = [NSString stringWithFormat: @"GPU : %.2fms", self->renderer.GPUTime * 1000];
    }];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

- (DeferredRenderer *)renderer {
    return (DeferredRenderer *)_view.renderer;
}

@end
