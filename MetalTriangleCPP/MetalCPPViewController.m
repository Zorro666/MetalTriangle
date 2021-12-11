#import "MetalCPPViewController.h"
#import "MetalCPPView.h"

typedef struct
{
  MetalCPPView *view;
  bool quit;
} ViewData;

@implementation MetalCPPViewController
{
  CVDisplayLinkRef _displayLink;
  NSTimer *_timer;
  ViewData viewData;
}

- (void)viewDidLoad
{
  [super viewDidLoad];

  MetalCPPView *metalView = (MetalCPPView*)self.view;
  viewData.quit = false;
  viewData.view = metalView;

  [metalView loaded];

  _timer = [NSTimer scheduledTimerWithTimeInterval: 0.2
                                            target: self
                                          selector: @selector(onTick:)
                                          userInfo: self
                                           repeats: YES];

  CVDisplayLinkCreateWithActiveCGDisplays(&_displayLink);
  CVDisplayLinkSetOutputCallback(_displayLink, &DisplayLinkCallback, (void *)(&self->viewData));
  CVDisplayLinkStart(_displayLink);

}

-(void)viewWillDisappear
{
  self->viewData.quit = true;
  [super viewWillDisappear];
}

-(void)onTick:(NSTimer*)timer
{
  if (self->viewData.quit) {
    [[[self view] window] close];
  }
}

static CVReturn DisplayLinkCallback(CVDisplayLinkRef displayLink, const CVTimeStamp *now,
                                    const CVTimeStamp *outputTime,
                                    CVOptionFlags flagsIn, CVOptionFlags *flagsOut, void *target) {
  ViewData *viewData = (ViewData*)target;
  MetalCPPView *view = viewData->view;
  [view draw];
  if (viewData->quit)
  {
    CVDisplayLinkStop(displayLink);
    CVDisplayLinkRelease(displayLink);
  }
  return kCVReturnSuccess;
}

@end
