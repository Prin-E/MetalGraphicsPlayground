//
//  AppDelegate.h
//  MetalEnvironmentMapping
//
//  Created by 이현우 on 2016. 12. 20..
//  Copyright © 2016년 Prin_E. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@import Metal;
@import MetalKit;
@import ModelIO;

@interface AppDelegate : NSObject <NSApplicationDelegate, MTKViewDelegate, NSWindowDelegate>

@property (nonatomic) float roughness, metalic;
@property (nonatomic) vector_float4 albedo;

- (IBAction)changeRoughness: (id)sender;
- (IBAction)changeMetalic: (id)sender;
- (IBAction)changeAlbedo: (id)sender;
@end

