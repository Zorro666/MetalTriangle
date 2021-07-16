@import Metal;

#import "MetalView.h"
#import <QuartzCore/CAMetalLayer.h>

@implementation MetalView
{
  id<MTLDevice> device;
  id<MTLRenderPipelineState> pipeline;
  id<MTLCommandQueue> commandQueue;
  id<MTLBuffer> positionBuffer;
  id<MTLBuffer> colorBuffer;

  CVDisplayLinkRef displayLink;
  CAMetalLayer *metalLayer;
}

- (BOOL)wantsUpdateLayer {
    return YES;
}

+ (Class)layerClass {
    return [CAMetalLayer class];
}

- (CALayer*)makeBackingLayer {
    CALayer* layer = [self.class.layerClass layer];
    CGSize viewScale = [self convertSizeToBacking:CGSizeMake(1.0, 1.0)];
    layer.contentsScale = MIN(viewScale.width, viewScale.height);
    return layer;
}

- (void)loaded
{
  [self buildDevice];
  [self buildVertexBuffers];
  [self buildPipeline];
}

- (void)buildDevice
{
    device = MTLCreateSystemDefaultDevice();
    metalLayer = (CAMetalLayer *)[self layer];
    metalLayer.device = device;
    metalLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;
}

- (void)buildPipeline
{
  id<MTLLibrary> library = [device newDefaultLibrary];
    
    id<MTLFunction> vertexFunc = [library newFunctionWithName:@"vertex_main"];
    id<MTLFunction> fragmentFunc = [library newFunctionWithName:@"fragment_main"];

    MTLRenderPipelineDescriptor *pipelineDescriptor = [MTLRenderPipelineDescriptor new];
    pipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    pipelineDescriptor.vertexFunction = vertexFunc;
    pipelineDescriptor.fragmentFunction = fragmentFunc;
    
    NSError *error = nil;
    pipeline = [device newRenderPipelineStateWithDescriptor:pipelineDescriptor
                                                                error:&error];
    
    if (!pipeline)
    {
        NSLog(@"Error occurred when creating render pipeline state: %@", error);
    }
    
  commandQueue = [device newCommandQueue];
}

- (void)buildVertexBuffers
{
    static const float positions[] =
    {
         0.0,  0.5, 0, 1,
        -0.5, -0.5, 0, 1,
         0.5, -0.5, 0, 1,
    };
    
    static const float colors[] =
    {
        1, 0, 0, 1,
        0, 1, 0, 1,
        0, 0, 1, 1,
    };
    
  positionBuffer = [device newBufferWithBytes:positions
                                                   length:sizeof(positions)
                                                  options:MTLResourceOptionCPUCacheModeDefault];
  colorBuffer = [device newBufferWithBytes:colors
                                                length:sizeof(colors)
                                               options:MTLResourceOptionCPUCacheModeDefault];
}

- (void)draw
{
  id<CAMetalDrawable> drawable = [metalLayer nextDrawable];
  id<MTLTexture> framebufferTexture = drawable.texture;
  
  MTLRenderPassDescriptor *renderPass = [MTLRenderPassDescriptor renderPassDescriptor];
  renderPass.colorAttachments[0].texture = framebufferTexture;
  renderPass.colorAttachments[0].clearColor = MTLClearColorMake(0.5, 0.5, 0.5, 1);
  renderPass.colorAttachments[0].storeAction = MTLStoreActionStore;
  renderPass.colorAttachments[0].loadAction = MTLLoadActionClear;

  id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];

  id<MTLRenderCommandEncoder> commandEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPass];
  [commandEncoder setRenderPipelineState:pipeline];
  [commandEncoder setVertexBuffer:positionBuffer offset:0 atIndex:0 ];
  [commandEncoder setVertexBuffer:colorBuffer offset:0 atIndex:1 ];
  [commandEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3 instanceCount:1];
  [commandEncoder endEncoding];
  
  [commandBuffer presentDrawable:drawable];
  [commandBuffer commit];
}

@end
