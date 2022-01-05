#import "MetalCPPViewController.h"
#import "MetalCPPView.h"

typedef struct
{
  MetalCPPView *view;
  bool quit;
} ViewData;

@implementation MetalCPPViewController
{
  ViewData viewData;
}

- (void)viewDidLoad
{
  [super viewDidLoad];

  MetalCPPView *metalView = (MetalCPPView*)self.view;
  viewData.quit = false;
  viewData.view = metalView;

  [metalView loaded];

  [NSTimer scheduledTimerWithTimeInterval: 0.2
                                            target: self
                                          selector: @selector(onTick:)
                                          userInfo: self
                                           repeats: YES];

  CVDisplayLinkRef displayLink;
  CVDisplayLinkCreateWithActiveCGDisplays(&displayLink);
  CVDisplayLinkSetOutputCallback(displayLink, &DisplayLinkCallback, (void *)(&self->viewData));
  CVDisplayLinkStart(displayLink);
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
  if (viewData->quit)
  {
    CVDisplayLinkStop(displayLink);
    CVDisplayLinkRelease(displayLink);
  }
  else
  {
    [view draw];
  }
  return kCVReturnSuccess;
}

@end
