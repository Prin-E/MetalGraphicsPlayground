//
//  MGPView.m
//  MetalDeferred
//
//  Created by 이현우 on 29/04/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

const inline __attribute__((__always_inline__)) float lerp(float a, float b, float t) {
    if(t < 0) t = 0;
    else if(t > 1) t = 1;
    return a * (1.0f - t) + b * t;
}

#import "MGPView.h"
#import "../Rendering/MGPRenderer.h"
@import CoreVideo;
@import QuartzCore;

@interface MGPView (Private)
// Metal
- (void)initMetalLayer;
- (void)render;

// Display link
- (void)initDisplayLink;
- (void)clearDisplayLink;

// Notifications
- (void)windowDidMinimize: (NSNotification *)n;
- (void)windowDidDeminimize: (NSNotification *)n;
- (void)windowWillClose: (NSNotification *)n;
@end

@implementation MGPView {
    MGPRenderer *_renderer;
    
    CAMetalLayer *_metalLayer;
    CVDisplayLinkRef _displayLinkRef;
    uint64_t _prevHostTime;
    
    dispatch_queue_t _renderQueue;
}

- (void)awakeFromNib {
    NSWindow *window = self.window;
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver: self
           selector: @selector(windowDidMinimize:)
               name: NSWindowDidMiniaturizeNotification
             object: window];
    [nc addObserver: self
           selector: @selector(windowDidDeminimize:)
               name: NSWindowDidDeminiaturizeNotification
             object: window];
    [nc addObserver: self
           selector: @selector(windowWillClose:)
               name: NSWindowWillCloseNotification
             object: window];
    
    _renderQueue = dispatch_queue_create("render queue", nil);
        
    // Init metal layer
    self.wantsLayer = YES;
    
    // accepts mouse events from window
    self.window.ignoresMouseEvents = NO;
    self.window.acceptsMouseMovedEvents = YES;
}

- (BOOL)wantsUpdateLayer {
    return YES;
}

- (CALayer *)makeBackingLayer {
    // Meke metal layer and set it as view's main layer.
    NSLog(@"Initializing metal layer...");
    _metalLayer = [CAMetalLayer layer];
    _metalLayer.pixelFormat = MTLPixelFormatBGRA8Unorm_sRGB;
    //_metalLayer.framebufferOnly = YES;
    //_metalLayer.displaySyncEnabled = NO;
    //_metalLayer.allowsNextDrawableTimeout = NO;
    return _metalLayer;
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (BOOL)becomeFirstResponder {
    return YES;
}

- (BOOL)resignFirstResponder {
    return YES;
}

- (MGPRenderer *)renderer {
    return _renderer;
}

- (void)setRenderer:(MGPRenderer *)renderer {
    _renderer = renderer;
    if(_renderer != nil) {
        _renderer.view = self;
        _metalLayer.device = _renderer.device;
        if(_metalLayer.device != nil) {
            NSRect pixelFrame = [self convertRectToBacking: self.frame];
            _metalLayer.drawableSize = pixelFrame.size;
            _currentDrawable = _metalLayer.nextDrawable;
            [self.renderer resize:pixelFrame.size];
            [self initDisplayLink];
        }
        else {
            NSLog(@"Null device...");
            [self clearDisplayLink];
        }
    }
    else {
        [self clearDisplayLink];
    }
}

- (void)initDisplayLink {
    if(_displayLinkRef != nil) return;
    NSLog(@"Initializing display link...");
    
    NSScreen *screen = self.window.screen;
    NSInteger screenNumber = [screen.deviceDescription[@"NSScreenNumber"] integerValue];
    CVDisplayLinkCreateWithCGDisplay((CGDirectDisplayID)screenNumber, &_displayLinkRef);
    
    _prevHostTime = CVGetCurrentHostTime();
    double clockFreq = CVGetHostClockFrequency();
    NSLog(@"Host time : %llu", _prevHostTime);
    NSLog(@"Host clock minimum time delta : %u", CVGetHostClockMinimumTimeDelta());
    NSLog(@"Host clock frequency : %lf", clockFreq);
    
    CVDisplayLinkSetOutputHandler(_displayLinkRef, ^CVReturn(CVDisplayLinkRef  _Nonnull displayLink, const CVTimeStamp * _Nonnull inNow, const CVTimeStamp * _Nonnull inOutputTime, CVOptionFlags flagsIn, CVOptionFlags * _Nonnull flagsOut) {
        // Increment frame counter, calculate delta time and fps.
        self->_currentFrame += 1;
        self->_deltaTime = (inNow->hostTime - self->_prevHostTime) / clockFreq;
        self->_currentFramesPerSecond = lerp(self->_currentFramesPerSecond, 1.0/self->_deltaTime, self->_deltaTime * 13.0f);
        /*
         if(self->_currentFrame % 60 == 0) {
         NSLog(@"1초 - video frame : %lld, host time : %lf", inNow->videoTime / inNow->videoRefreshPeriod, inNow->hostTime / clockFreq);
         }
         */
        [self render];
        self->_prevHostTime = inNow->hostTime;
        
        return kCVReturnSuccess;
    });
    CVDisplayLinkStart(_displayLinkRef);
}

- (void)clearDisplayLink {
    if(_displayLinkRef != nil) {
        if(CVDisplayLinkIsRunning(_displayLinkRef))
            CVDisplayLinkStop(_displayLinkRef);
        CVDisplayLinkRelease(_displayLinkRef);
        _displayLinkRef = nil;
    }
}

- (void)render {
    static NSString *windowTitle = nil;
    dispatch_sync(dispatch_get_main_queue(), ^{
        // Display FPS, DeltaTime
        static float elapsed = 0.0f;
        elapsed += self->_deltaTime;
        if(elapsed >= 1.0f) {
            elapsed -= 1.0f;
            if(!windowTitle)
                windowTitle = self.window.title;
            self.window.title = [NSString stringWithFormat: @"%@ (FPS : %.0f, CPU: %.1fms, GPU: %.1fms)", windowTitle, self->_currentFramesPerSecond, self.renderer.CPUTime*1000, self.renderer.GPUTime*1000];
        }
        
        // Render
        [self.renderer update: self->_deltaTime];
        [self.renderer beginFrame];
        [self.renderer render];
        [self.renderer endFrame];
        
        // Next drawable
        id<CAMetalDrawable> nextDrawable = self->_metalLayer.nextDrawable;
        self->_currentDrawable = nextDrawable;
    });
}

- (void)keyDown:(NSEvent *)event {
    if([_delegate respondsToSelector:@selector(view:keyDown:)]) {
        [_delegate view: self keyDown: event];
    }
}

- (void)keyUp:(NSEvent *)event {
    if([_delegate respondsToSelector:@selector(view:keyUp:)]) {
        [_delegate view: self keyUp: event];
    }
}

- (void)flagsChanged:(NSEvent *)event {
    if([_delegate respondsToSelector:@selector(view:flagsChanged:)]) {
        [_delegate view: self flagsChanged: event];
    }
}

- (void)mouseDown:(NSEvent *)event {
    if([_delegate respondsToSelector:@selector(view:mouseDown:)]) {
        [_delegate view: self mouseDown: event];
    }
}

- (void)mouseMoved:(NSEvent *)event {
    if([_delegate respondsToSelector:@selector(view:mouseMoved:)]) {
        [_delegate view: self mouseMoved: event];
    }
}

- (void)mouseDragged:(NSEvent *)event {
    if([_delegate respondsToSelector:@selector(view:mouseDragged:)]) {
        [_delegate view: self mouseDragged: event];
    }
}

- (void)mouseUp:(NSEvent *)event {
    if([_delegate respondsToSelector:@selector(view:mouseUp:)]) {
        [_delegate view: self mouseUp: event];
    }
}

- (void)setFrame:(NSRect)frame {
    [super setFrame:frame];
    NSRect pixelFrame = [self convertRectToBacking:frame];
    CGSize pixelSize = pixelFrame.size;
    pixelSize.width = MAX(1, pixelSize.width);
    pixelSize.height = MAX(1, pixelSize.height);
    _metalLayer.drawableSize = pixelSize;
    if(_metalLayer.device)
        _currentDrawable = _metalLayer.nextDrawable;
    [self.renderer resize:pixelSize];
    //NSLog(@"New frame pixel size : %@", NSStringFromSize(pixelFrame.size));
}

- (void)windowDidMinimize: (NSNotification *)n {
    if(_displayLinkRef != nil) {
        if(CVDisplayLinkIsRunning(_displayLinkRef))
            CVDisplayLinkStop(_displayLinkRef);
    }
}

- (void)windowDidDeminimize: (NSNotification *)n {
    if(_displayLinkRef != nil) {
        if(!CVDisplayLinkIsRunning(_displayLinkRef))
            CVDisplayLinkStart(_displayLinkRef);
    }
}

- (void)windowWillClose:(NSNotification *)n {
    [NSApp terminate: self];
}

- (void)dealloc {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc removeObserver: self];
    [self clearDisplayLink];
}

@end
