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

@implementation AppDelegate {
    DeferredRenderer *renderer;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    renderer = [[DeferredRenderer alloc] init];
    self.view.renderer = renderer;
    self.roughness = 0.5f;
    self.metalic = 0.5f;
    self.numLights = 4;
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

- (float)roughness {
    return renderer.roughness;
}

- (void)setRoughness:(float)roughness {
    renderer.roughness = roughness;
}

- (float)metalic {
    return renderer.metalic;
}

- (void)setMetalic:(float)metalic {
    renderer.metalic = metalic;
}

- (unsigned int)numLights {
    return renderer.numLights;
}

- (void)setNumLights:(unsigned int)numLights {
    renderer.numLights = numLights;
}


@end
