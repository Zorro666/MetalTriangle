@import Metal;

#import "MetalView.h"
#import <QuartzCore/CAMetalLayer.h>
#import <simd/simd.h>

typedef struct Debug_UBO
{
  simd_float4 lightCol;
  simd_float4 darkCol;
  simd_float4 constants;
} Debug_UBO;

NSString* debugShaders = @"\n\
using namespace metal;\n\
\n\
struct Debug_UBO\n\
{\n\
  float4 lightCol;\n\
  float4 darkCol;\n\
  float4 constants;\n\
};\n\
\n\
struct UVVertex\n\
{\n\
  float4 position [[position]];\n\
  float2 uv;\n\
};\n\
\n\
vertex UVVertex blit_vertex(uint vid [[vertex_id]])\n\
{\n\
  const float4 verts[4] = {\n\
                            float4(-1.0, -1.0, 0.5, 1.0),\n\
                            float4(1.0, -1.0, 0.5, 1.0),\n\
                            float4(-1.0, 1.0, 0.5, 1.0),\n\
                            float4(1.0, 1.0, 0.5, 1.0)\n\
                          };\n\
  UVVertex vert;\n\
  vert.position = verts[vid];\n\
  vert.uv = vert.position.xy * 0.5f + 0.5f;\n\
  return vert;\n\
}\n\
\n\
vertex UVVertex vertex_main(constant float4 *position [[buffer(0)]],\n\
                             constant float2 *uv [[buffer(1)]],\n\
                             uint vid [[vertex_id]])\n\
{\n\
  UVVertex vert;\n\
  vert.position = position[vid];\n\
  vert.uv = uv[vid];\n\
  return vert;\n\
}\n\
\n\
fragment float4 fragment_main(constant Debug_UBO& debug_UBO [[buffer(0)]],\n\
               UVVertex vert [[stage_in]],\n\
               texture2d<float> colorTexture [[texture(0)]])\n\
{\n\
  float4 pos(vert.position);\n\
  float2 uv(vert.uv);\n\
  constexpr sampler textureSampler (mag_filter::linear, min_filter::linear);\n\
  const float4 colorSample = colorTexture.sample(textureSampler, uv);\n\
\n\
  float screenWidth = debug_UBO.constants.x;\n\
  float screenHeight = debug_UBO.constants.y;\n\
  float grid = debug_UBO.constants.z;\n\
  float4 lightCol = debug_UBO.lightCol;\n\
  float4 darkCol = debug_UBO.darkCol;\n\
\n\
  float2 RectRelativePos = pos.xy;\n\
  float2 ab = fmod(RectRelativePos.xy, float2(grid * 2.0));\n\
  bool checkerVariant =\n\
         ((ab.x < grid && ab.y < grid) ||\n\
          (ab.x > grid && ab.y > grid));\n\
  float4 outputCol = checkerVariant ? lightCol : darkCol;\n\
\n\
  outputCol *= colorSample;\n\
  return outputCol;\n\
}\n\
";

@implementation MetalView
{
  id<MTLDevice> device;
  id<MTLRenderPipelineState> pipeline;
  id<MTLCommandQueue> commandQueue;
  id<MTLBuffer> positionBuffer;
  id<MTLBuffer> colorBuffer;

  id<MTLRenderPipelineState> debugPipeline;
  id<MTLBuffer> debugUBOBuffer;

  id<MTLTexture> fb1;

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

- (void)viewDidEndLiveResize {
  CGSize viewScale = [self convertSizeToBacking:CGSizeMake(1.0, 1.0)];
  self.layer.contentsScale = MIN(viewScale.width, viewScale.height);
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
  NSLog(@"device name:'%@' registryID:%llu maxThreadsPerThreadgroup:%lu,%lu,%lu",
        device.name,
        device.registryID,
        device.maxThreadsPerThreadgroup.width,
        device.maxThreadsPerThreadgroup.height,
        device.maxThreadsPerThreadgroup.depth);
  NSLog(@"device lowPower:%d isLowPower:%d headless:%d removable:%d hasUnifiedMemory:%d recommendedMaxWorkingSetSize:%llu",
        device.lowPower,
        device.isLowPower,
        device.headless,
        device.removable,
        device.hasUnifiedMemory,
        device.recommendedMaxWorkingSetSize);
  NSLog(@"device location:%lu locationNumber:%lu maxTransferRate:%llu",
        device.location,
        device.locationNumber,
        device.maxTransferRate);
  NSLog(@"device depth24Stencil8PixelFormatSupported:%d readWriteTextureSupport:%lu argumentBuffersSupport:%lu areRasterOrderGroupsSupported:%d",
        device.depth24Stencil8PixelFormatSupported,
        (unsigned long)device.readWriteTextureSupport,
        (unsigned long)device.argumentBuffersSupport,
        device.areRasterOrderGroupsSupported);
  metalLayer = (CAMetalLayer *)[self layer];
  metalLayer.device = device;
  metalLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;
  metalLayer.framebufferOnly = YES;
}

- (void)buildPipeline
{
  NSError *error = nil;
  NSBundle *appBundle = [NSBundle mainBundle];
  NSString *defaultLibaryPath = [appBundle pathForResource:@"default" ofType:@"metallib"];
  NSData *myData = [NSData dataWithContentsOfFile:defaultLibaryPath];
  dispatch_data_t data = dispatch_data_create(myData.bytes, myData.length, dispatch_get_main_queue(), DISPATCH_DATA_DESTRUCTOR_DEFAULT);
  NSData *jake = (NSData*)data;
  NSLog(@"\nPtr:%p count %lu\n", (void*)(jake.bytes), (unsigned long)jake.length);
  [data release];
/*
  id<MTLLibrary> library = [device newLibraryWithData:data error:&error];
  //id<MTLLibrary> library = [device newLibraryWithFile:defaultLibaryPath error:&error];
  if (!library) {
      NSLog(@"Failed to load library. error %@", error);
      exit(0);
  }
*/
  id<MTLLibrary> library = [device newDefaultLibrary];
  if (!library)
  {
    NSLog(@"Error occurred when creating default library");
  }
  NSLog(@"Library.device %p name:'%@' registryID:%llu maxThreadsPerThreadgroup:%lu,%lu,%lu",
        (__bridge void*)library.device,
        library.device.name,
        library.device.registryID,
        library.device.maxThreadsPerThreadgroup.width,
        library.device.maxThreadsPerThreadgroup.height,
        library.device.maxThreadsPerThreadgroup.depth);
  
  id<MTLFunction> vertexFunc = [library newFunctionWithName:@"vertex_main"];
  id<MTLFunction> fragmentFunc = [library newFunctionWithName:@"fragment_main"];
  
  MTLRenderPipelineDescriptor *pipelineDescriptor = [MTLRenderPipelineDescriptor new];
  pipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
  pipelineDescriptor.vertexFunction = vertexFunc;
  pipelineDescriptor.fragmentFunction = fragmentFunc;

  pipeline = [device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];
  
  if (!pipeline)
  {
    NSLog(@"Error occurred when creating render pipeline state: %@", error);
  }

  id<MTLLibrary> debugLibrary = [device newLibraryWithSource:debugShaders options:NULL error:&error];
  if (!debugLibrary)
  {
    NSLog(@"Error occurred when creating debug library\n%@", error);
  }

  id<MTLFunction> debugVertexFunc = [debugLibrary newFunctionWithName:@"vertex_main"];
  if (!debugVertexFunc)
  {
    NSLog(@"Error finding shader function 'vertex_main'\n");
  }

  id<MTLFunction> blitVertexFunc = [debugLibrary newFunctionWithName:@"blit_vertex"];
  if (!blitVertexFunc)
  {
    NSLog(@"Error finding shader function 'blit_vertex'\n");
  }

  id<MTLFunction> debugFragmentFunc = [debugLibrary newFunctionWithName:@"fragment_main"];
  if (!debugFragmentFunc)
  {
    NSLog(@"Error finding shader function 'fragment_main'\n");
  }

  MTLRenderPipelineDescriptor *debugPipelineDescriptor = [MTLRenderPipelineDescriptor new];
  debugPipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
  debugPipelineDescriptor.vertexFunction = blitVertexFunc;
  debugPipelineDescriptor.fragmentFunction = debugFragmentFunc;
  debugPipelineDescriptor.alphaToOneEnabled = YES;

  MTLTextureDescriptor *textureDescriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm width:1024 height:1024 mipmapped:NO];
  textureDescriptor.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
  textureDescriptor.usage = MTLTextureUsageUnknown;
  fb1 = [device newTextureWithDescriptor:textureDescriptor];

  debugPipeline = [device newRenderPipelineStateWithDescriptor:debugPipelineDescriptor error:&error];

  commandQueue = [device newCommandQueue];
  commandQueue.label=@"JakeQueue";
  NSLog(@"commandQueue label:'%@", commandQueue.label);

  [pipelineDescriptor release];
  [vertexFunc release];
  [fragmentFunc release];
  [debugVertexFunc release];
  [debugFragmentFunc release];
  [blitVertexFunc release];
  [debugPipelineDescriptor release];
  [debugLibrary release];
  [library release];
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
    1.0f, 0.0f, 0.0f, 1.0f,
    0.0f, 1.0f, 0.0f, 1.0f,
    0.0f, 0.0f, 1.0f, 1.0f,
  };

  positionBuffer = [device newBufferWithBytes:positions
                                       length:sizeof(positions)
                                      options:MTLResourceOptionCPUCacheModeDefault];
  colorBuffer = [device newBufferWithBytes:colors
                                    length:sizeof(colors)
                                   options:MTLResourceOptionCPUCacheModeDefault];
  debugUBOBuffer = [device newBufferWithLength:sizeof(Debug_UBO) options:MTLResourceStorageModeShared];
}

- (void)draw
{
  id<CAMetalDrawable> drawable = [metalLayer nextDrawable];
  id<MTLTexture> framebufferTexture = drawable.texture;
  MTLRenderPassDescriptor *renderPass1 = [MTLRenderPassDescriptor renderPassDescriptor];
  renderPass1.colorAttachments[0].texture = fb1;
  renderPass1.colorAttachments[0].clearColor = MTLClearColorMake(1.0, 1.0, 1.0, 1);
  renderPass1.colorAttachments[0].storeAction = MTLStoreActionStore;
  renderPass1.colorAttachments[0].loadAction = MTLLoadActionClear;
  
  id<MTLCommandBuffer> commandBuffer1 = [commandQueue commandBuffer];

  id<MTLRenderCommandEncoder> commandEncoder = [commandBuffer1 renderCommandEncoderWithDescriptor:renderPass1];
  [commandEncoder setRenderPipelineState:pipeline];
  [commandEncoder setVertexBuffer:positionBuffer offset:0 atIndex:0 ];
  [commandEncoder setVertexBuffer:colorBuffer offset:0 atIndex:1 ];
  [commandEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3 instanceCount:1];
  [commandEncoder endEncoding];
 
  [commandBuffer1 commit];
  id<MTLCommandBuffer> commandBuffer2 = [commandQueue commandBuffer];
  Debug_UBO* debug_UBO = debugUBOBuffer.contents;
  debug_UBO->constants.x = framebufferTexture.width;
  debug_UBO->constants.y = framebufferTexture.height;
  debug_UBO->constants.z = 128.0f;
  debug_UBO->lightCol = simd_make_float4(2 * 0.117647059f, 2 * 0.215671018f, 2 * 0.235294119f, 1.0f);
  debug_UBO->darkCol = simd_make_float4(2 * 0.176470593f, 2 * 0.14378576f, 2 * 0.156862751f, 1.0f);

  MTLRenderPassDescriptor *renderPass2 = [MTLRenderPassDescriptor renderPassDescriptor];
  renderPass2.colorAttachments[0].texture = framebufferTexture;
  renderPass2.colorAttachments[0].clearColor = MTLClearColorMake(1.0, 1.0, 1.0, 1);
  renderPass2.colorAttachments[0].storeAction = MTLStoreActionStore;
  renderPass2.colorAttachments[0].loadAction = MTLLoadActionLoad;
  commandEncoder = [commandBuffer2 renderCommandEncoderWithDescriptor:renderPass2];

  MTLViewport viewport;
  viewport.originX = 0.0f;
  viewport.originY = 0.0f;
  viewport.width = framebufferTexture.width;
  viewport.height = framebufferTexture.height;
  viewport.znear = 0.0;
  viewport.zfar = 1.0f;
  [commandEncoder setRenderPipelineState:debugPipeline];
  [commandEncoder setFragmentBuffer:debugUBOBuffer offset:0 atIndex:0];
  [commandEncoder setFragmentTexture:fb1 atIndex:0];
  [commandEncoder setViewport:viewport];
  [commandEncoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4 instanceCount:1];
  [commandEncoder endEncoding];

  [commandBuffer2 presentDrawable:drawable];
  static float jake = 0.0f;
  jake += 0.01f;
  jake = (jake > 1.0f) ? 0.0f : jake;
  debug_UBO->darkCol = simd_make_float4(jake, 0.0f, 0.0f, 1.0f);
  [commandBuffer2 commit];
}

-(void)copyFrameBuffer:(id<MTLTexture>)framebuffer
{
  id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];
  id<MTLBlitCommandEncoder> blitEncoder = [commandBuffer blitCommandEncoder];

  NSUInteger sourceWidth = framebuffer.width;
  NSUInteger sourceHeight = framebuffer.height;
  MTLOrigin sourceOrigin = MTLOriginMake(0,0,0);
  MTLSize sourceSize = MTLSizeMake(sourceWidth, sourceHeight, 1);

  NSUInteger bytesPerPixel = 4;
  NSUInteger bytesPerRow   = sourceWidth * bytesPerPixel;
  NSUInteger bytesPerImage = sourceHeight * bytesPerRow;

  id<MTLBuffer> cpuPixelBuffer = [self->device newBufferWithLength:bytesPerImage options:MTLResourceStorageModeShared];

  [blitEncoder copyFromTexture:framebuffer
                   sourceSlice:0
                   sourceLevel:0
                  sourceOrigin:sourceOrigin
                    sourceSize:sourceSize
                      toBuffer:cpuPixelBuffer
             destinationOffset:0
        destinationBytesPerRow:bytesPerRow
      destinationBytesPerImage:bytesPerImage];
  [blitEncoder endEncoding];

  [commandBuffer commit];
  [commandBuffer waitUntilCompleted];
  static int jake = 0;
  if (jake % 1000 == 0)
  {
    uint32_t *pixels = (uint32_t *)cpuPixelBuffer.contents;
    NSLog(@"0x%X 0x%X 0x%X 0x%X\n", pixels[sourceWidth/2 + sourceHeight/2 * sourceWidth],
          pixels[sourceWidth/2 + sourceHeight*2/3 * sourceWidth],
          pixels[sourceWidth*3/5 + sourceHeight/2 * sourceWidth],
          pixels[sourceWidth/2 + sourceHeight/3 * sourceWidth]);
    [cpuPixelBuffer release];
  }
  ++jake;
}

@end
