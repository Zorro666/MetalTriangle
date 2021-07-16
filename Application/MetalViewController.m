#import "MetalViewController.h"
#import "MetalView.h"
#import <Metal/MTLDevice.h>

@implementation MetalViewController
{
  CVDisplayLinkRef _displayLink;
  NSTimer* _timer;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  MetalView* metalView = (MetalView*)self.view;

  [metalView loaded];
  
  _timer = [NSTimer scheduledTimerWithTimeInterval: 0.2
                                            target: self
                                          selector: @selector(onTick:)
                                          userInfo: self
                                           repeats: YES];

  CVDisplayLinkCreateWithActiveCGDisplays(&_displayLink);
  CVDisplayLinkSetOutputCallback(_displayLink, &DisplayLinkCallback, (__bridge void * _Nullable)(self.view));
  CVDisplayLinkStart(_displayLink);

}

-(void)onTick:(NSTimer*)timer
{
/*
 if (quit) {
        [[[self view] window] close];
    }
 */
}

static CVReturn DisplayLinkCallback(CVDisplayLinkRef displayLink, const CVTimeStamp* now,
                                    const CVTimeStamp* outputTime,
                                    CVOptionFlags flagsIn, CVOptionFlags* flagsOut, void* target) {
  MetalView* view = (__bridge MetalView*)target;
  [view draw];
/*
 if (demo->quit) {
        CVDisplayLinkStop(displayLink);
        CVDisplayLinkRelease(displayLink);
    }
 */
    return kCVReturnSuccess;
}


@end
