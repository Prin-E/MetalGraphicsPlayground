//
//  AppDelegate.m
//  MetalDeferred
//
//  Created by 이현우 on 29/04/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import "AppDelegate.h"
#import "../Common/MGPView.h"
#import "DeferredRenderer.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    DeferredRenderer *renderer = [[DeferredRenderer alloc] init];
    self.view.renderer = renderer;
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}


@end
