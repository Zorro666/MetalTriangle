//@import Metal;

#import "MetalCPPView.h"
#import "MetalDraw.h"
#import <QuartzCore/CAMetalLayer.h>

@implementation MetalCPPView
{
  CVDisplayLinkRef displayLink;
  CAMetalLayer *metalLayer;
  MetalDraw *metalDraw;
}

- (BOOL)wantsUpdateLayer {
  return YES;
}

+ (Class)layerClass {
  return [CAMetalLayer class];
}

- (CALayer*)makeBackingLayer {

  CALayer *layer = [self.class.layerClass layer];
  CGSize viewScale = [self convertSizeToBacking:CGSizeMake(1.0, 1.0)];
  layer.contentsScale = MIN(viewScale.width, viewScale.height);
  return layer;
}

- (void)viewDidEndLiveResize {
  CGSize viewScale = [self convertSizeToBacking:CGSizeMake(1.0, 1.0)];
  self.layer.contentsScale = MIN(viewScale.width, viewScale.height);
}

- (void)loaded
{
  @autoreleasepool
  {
    metalDraw = CreateMetalDraw();
    NSBundle *appBundle = [NSBundle mainBundle];
    NSString *defaultLibaryPath = [appBundle pathForResource:@"default" ofType:@"metallib"];
    NSData *myData = [NSData dataWithContentsOfFile:defaultLibaryPath];

    metalDraw->Loaded((__bridge NS::String*)defaultLibaryPath, (__bridge NS::Data*)myData);
    metalLayer = (CAMetalLayer *)[self layer];
    assert(metalLayer);
    metalLayer.device = (__bridge id<MTLDevice>)metalDraw->device;
    metalLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    metalLayer.framebufferOnly = YES;
  }
}

- (void)draw
{
  @autoreleasepool
  {
    id<CAMetalDrawable> drawable = [metalLayer nextDrawable];
    CA::MetalDrawable *pMetalCppDrawable  = (__bridge CA::MetalDrawable*)drawable;
    metalDraw->Draw(pMetalCppDrawable);
  }
}

@end
