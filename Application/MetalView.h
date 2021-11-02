#import <Cocoa/Cocoa.h>

@interface MetalView : NSView

- (void)loaded;
- (void)draw;
-(void)copyFrameBuffer:(id<MTLTexture>)framebuffer;

@end
