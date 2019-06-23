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
}

@property (weak) IBOutlet NSWindow *window;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    renderer = [[DeferredRenderer alloc] init];
    _view.renderer = renderer;
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}


@end
