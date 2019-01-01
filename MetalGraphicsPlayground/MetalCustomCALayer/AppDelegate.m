//
//  AppDelegate.m
//  MetalCustomCALayer
//
//  Created by 이현우 on 31/12/2018.
//  Copyright © 2018 Prin_E. All rights reserved.
//

#import "AppDelegate.h"
#import "CustomMetalLayerView.h"
#import "SimpleMetalRenderer.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@property (weak) IBOutlet CustomMetalLayerView *metalView;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    _window.delegate = self;
    _metalView.renderer = [SimpleMetalRenderer new];
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

- (void)windowDidChangeScreen:(NSNotification *)notification {
    NSLog(@"windowDidChangeScreen:");
}

- (void)windowDidChangeBackingProperties:(NSNotification *)notification {
    NSLog(@"windowDidChangeBackingProperties:");
}


@end
