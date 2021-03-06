//
//  AppDelegate.h
//  MetalDeferred
//
//  Created by 이현우 on 29/04/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class MGPView;
@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (weak) IBOutlet MGPView *view;
@property (readwrite) float roughness, metalic, anisotropy;
@property (readwrite) unsigned int numLights;
@property (readwrite) BOOL showsTestObjects;

@end

