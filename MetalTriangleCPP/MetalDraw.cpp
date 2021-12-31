//
//  MetalDraw.cpp
//  MetalTriangleCPP
//
//  Created by Jake on 10/12/2021.
//  Copyright © 2021 Apple. All rights reserved.
//

#include "MetalDraw.h"

#import <simd/simd.h>

typedef struct Debug_UBO
{
  simd_float4 lightCol;
  simd_float4 darkCol;
  simd_float4 constants;
} Debug_UBO;

const char *debugShaders = "\n\
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

MetalDraw *CreateMetalDraw()
{
  return new MetalDraw;
}

void MetalDraw::Loaded(NS::String *defaultLibraryPath, NS::Data *defaultLibraryData)
{
  BuildDevice();
  BuildVertexBuffers();
  BuildPipeline(defaultLibraryPath, defaultLibraryData);
}

void MetalDraw::BuildDevice()
{
  device = MTL::CreateSystemDefaultDevice();
  printf("device name:'%s' registryID:%llu maxThreadsPerThreadgroup:%lu,%lu,%lu\n",
        device->name()->cString(NS::UTF8StringEncoding),
        device->registryID(),
        device->maxThreadsPerThreadgroup().width,
        device->maxThreadsPerThreadgroup().height,
        device->maxThreadsPerThreadgroup().depth);
  printf("device lowPower:%d headless:%d removable:%d hasUnifiedMemory:%d recommendedMaxWorkingSetSize:%llu\n",
        device->lowPower(),
        device->headless(),
        device->removable(),
        device->hasUnifiedMemory(),
        device->recommendedMaxWorkingSetSize());
  printf("device location:%lu locationNumber:%lu maxTransferRate:%llu\n",
        device->location(),
        device->locationNumber(),
        device->maxTransferRate());
  printf("device depth24Stencil8PixelFormatSupported:%d readWriteTextureSupport:%lu argumentBuffersSupport:%lu areRasterOrderGroupsSupported:%d\n",
        device->depth24Stencil8PixelFormatSupported(),
        (unsigned long)device->readWriteTextureSupport(),
        (unsigned long)device->argumentBuffersSupport(),
         device->rasterOrderGroupsSupported());
}

void MetalDraw::BuildPipeline(NS::String *defaultLibraryPath, NS::Data *defaultLibraryData)
{
  NS::Error *error;
  NS::String *nsString = NS::String::alloc();
  NS::String *tempString = nullptr;

  /*
  dispatch_data_t data = dispatch_data_create(defaultLibraryData->mutableBytes(), defaultLibraryData->length(), dispatch_get_main_queue(), DISPATCH_DATA_DESTRUCTOR_DEFAULT);
  MTL::Library *dataLibrary = device->newLibrary(data, &error);
  printf("\nPtr:%p count %lu\n", defaultLibraryData->mutableBytes(), defaultLibraryData->length());
  defaultLibraryPath->release();
  if (!dataLibrary) {
    fprintf(stderr, "Failed to load library error %s\n", error->description()->utf8String());
    exit(0);
  }
  */
  /*
  MTL::Library *fileLibrary = device->newLibrary(defaultLibraryPath, &error);
  if (!fileLibrary)
  {
    fprintf(stderr, "Failed to load library '%s' error %s\n", defaultLibraryPath->utf8String(), error->description()->utf8String());
    exit(0);
  }
  */
  MTL::Library *library = device->newDefaultLibrary();
  if (!library)
  {
    fprintf(stderr, "Error occurred when creating default library\n");
    exit(0);
  }
  printf("Library.device %p name:'%s' registryID:%llu maxThreadsPerThreadgroup:%lu,%lu,%lu\n",
        library->device(),
        library->device()->name()->utf8String(),
        library->device()->registryID(),
        library->device()->maxThreadsPerThreadgroup().width,
        library->device()->maxThreadsPerThreadgroup().height,
        library->device()->maxThreadsPerThreadgroup().depth);

  tempString = nsString->init("vertex_main", NS::UTF8StringEncoding);
  MTL::Function *vertexFunc = library->newFunction(tempString);
  tempString->release();
  tempString = nullptr;

  tempString = nsString->init("fragment_main", NS::UTF8StringEncoding);
  MTL::Function *fragmentFunc = library->newFunction(tempString);
  tempString->release();
  tempString = nullptr;

  MTL::RenderPipelineDescriptor *pipelineDescriptor = nullptr;
  pipelineDescriptor = pipelineDescriptor->alloc();
  pipelineDescriptor->init();

  MTL::RenderPipelineColorAttachmentDescriptorArray *colorAttachments = pipelineDescriptor->colorAttachments();
  MTL::RenderPipelineColorAttachmentDescriptor *colorAttachment0 = colorAttachments->object(0);
  colorAttachment0->setPixelFormat(MTL::PixelFormat::PixelFormatBGRA8Unorm);
  colorAttachments->setObject(colorAttachment0, 0);
  pipelineDescriptor->setVertexFunction(vertexFunc);
  pipelineDescriptor->setFragmentFunction(fragmentFunc);

  pipeline = device->newRenderPipelineState(pipelineDescriptor, &error);
  if (!pipeline)
  {
    fprintf(stderr, "Error occurred when creating render pipeline state: %s\n", error->description()->utf8String());
    exit(0);
  }

  tempString = nsString->init(debugShaders, NS::UTF8StringEncoding);
  MTL::Library *debugLibrary = device->newLibrary(tempString, NULL, &error);
  tempString->release();
  tempString = nullptr;
  if (!debugLibrary)
  {
    fprintf(stderr, "Error occurred when creating debug library : %s\n", error->description()->utf8String());
    exit(0);
  }

  tempString = nsString->init("vertex_main", NS::UTF8StringEncoding);
  MTL::Function *debugVertexFunc = debugLibrary->newFunction(tempString);
  tempString->release();
  tempString = nullptr;
  if (!debugVertexFunc)
  {
    fprintf(stderr, "Error finding shader function 'vertex_main'\n");
    exit(0);
  }

  tempString = nsString->init("blit_vertex", NS::UTF8StringEncoding);
  MTL::Function *blitVertexFunc = debugLibrary->newFunction(tempString);
  tempString->release();
  tempString = nullptr;
  if (!blitVertexFunc)
  {
    fprintf(stderr, "Error finding shader function 'blit_vertex'\n");
    exit(0);
  }

  tempString = nsString->init("fragment_main", NS::UTF8StringEncoding);
  MTL::Function *debugFragmentFunc = debugLibrary->newFunction(tempString);
  tempString->release();
  if (!debugFragmentFunc)
  {
    fprintf(stderr, "Error finding shader function 'fragment_main'\n");
    exit(0);
  }

  MTL::RenderPipelineDescriptor *debugPipelineDescriptor = nullptr;
  debugPipelineDescriptor = debugPipelineDescriptor->alloc();
  debugPipelineDescriptor->init();
  colorAttachments = debugPipelineDescriptor->colorAttachments();
  colorAttachment0 = colorAttachments->object(0);
  colorAttachment0->setPixelFormat(MTL::PixelFormat::PixelFormatBGRA8Unorm);
  colorAttachments->setObject(colorAttachment0, 0);
  debugPipelineDescriptor->setVertexFunction(blitVertexFunc);
  debugPipelineDescriptor->setFragmentFunction(debugFragmentFunc);
  debugPipelineDescriptor->setAlphaToOneEnabled(true);

  MTL::TextureDescriptor *textureDescriptor = nullptr;
  textureDescriptor = textureDescriptor->texture2DDescriptor(MTL::PixelFormat::PixelFormatBGRA8Unorm, 1024, 1024, false);
  textureDescriptor->setUsage(MTL::TextureUsageRenderTarget | MTL::TextureUsageShaderRead);
  textureDescriptor->setUsage(MTL::TextureUsageUnknown);
  fb1 = device->newTexture(textureDescriptor);

  debugPipeline = device->newRenderPipelineState(debugPipelineDescriptor, &error);
  if (!debugPipeline)
  {
    fprintf(stderr, "Error creating debugPipeline %s\n", error->description()->utf8String());
    exit(0);
  }

  commandQueue = device->newCommandQueue();
  tempString = nsString->init("JakeQueue", NS::UTF8StringEncoding);
  commandQueue->setLabel(tempString);
  tempString->release();
  tempString = nullptr;
  printf("commandQueue label:'%s'\n", commandQueue->label()->utf8String());

  pipelineDescriptor->release();
  vertexFunc->release();
  fragmentFunc->release();
  debugVertexFunc->release();
  debugFragmentFunc->release();
  blitVertexFunc->release();
  debugPipelineDescriptor->release();
  debugLibrary->release();
  library->release();
  nsString->release();
}

void MetalDraw::BuildVertexBuffers()
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

  positionBuffer = device->newBuffer(positions, sizeof(positions), MTL::ResourceOptionCPUCacheModeDefault);
  colorBuffer = device->newBuffer(colors, sizeof(colors), MTL::ResourceOptionCPUCacheModeDefault);
  debugUBOBuffer = device->newBuffer(sizeof(Debug_UBO), MTL::ResourceStorageModeShared);
}

void MetalDraw::Draw(CA::MetalDrawable *pMetalDrawable)
{
  MTL::Texture *framebufferTexture = pMetalDrawable->texture();
  MTL::RenderPassDescriptor *renderPass1 = MTL::RenderPassDescriptor::renderPassDescriptor();
  MTL::RenderPassColorAttachmentDescriptorArray *colorAttachments1 = renderPass1->colorAttachments();
  colorAttachments1->object(0)->setTexture(fb1);
  colorAttachments1->object(0)->setClearColor(MTL::ClearColor(1.0, 1.0, 1.0, 1.0));
  colorAttachments1->object(0)->setStoreAction(MTL::StoreActionStore);
  colorAttachments1->object(0)->setLoadAction(MTL::LoadActionClear);

  MTL::CommandBuffer *commandBuffer1 = commandQueue->commandBuffer();

  MTL::RenderCommandEncoder *commandEncoder1 = commandBuffer1->renderCommandEncoder(renderPass1);
  renderPass1->release();
  commandEncoder1->setRenderPipelineState(pipeline);
  commandEncoder1->setVertexBuffer(positionBuffer, 0, 0);
  commandEncoder1->setVertexBuffer(colorBuffer, 0, 1);
  commandEncoder1->drawPrimitives(MTL::PrimitiveTypeTriangle, 0, 3, 1);
  commandEncoder1->endEncoding();
  commandEncoder1->release();

  commandBuffer1->commit();
  commandBuffer1->release();
  MTL::CommandBuffer *commandBuffer2 = commandQueue->commandBuffer();
  Debug_UBO *debug_UBO = (Debug_UBO*)debugUBOBuffer->contents();
  debug_UBO->constants.x = framebufferTexture->width();
  debug_UBO->constants.y = framebufferTexture->height();
  debug_UBO->constants.z = 128.0f;
  debug_UBO->lightCol = simd_make_float4(2 * 0.117647059f, 2 * 0.215671018f, 2 * 0.235294119f, 1.0f);
  debug_UBO->darkCol = simd_make_float4(2 * 0.176470593f, 2 * 0.14378576f, 2 * 0.156862751f, 1.0f);

  MTL::RenderPassDescriptor *renderPass2 = MTL::RenderPassDescriptor::renderPassDescriptor();
  MTL::RenderPassColorAttachmentDescriptorArray *colorAttachments2 = renderPass2->colorAttachments();
  colorAttachments2->object(0)->setTexture(framebufferTexture);
  colorAttachments2->object(0)->setClearColor(MTL::ClearColor(1.0, 1.0, 1.0, 1.0));
  colorAttachments2->object(0)->setStoreAction(MTL::StoreActionStore);
  colorAttachments2->object(0)->setLoadAction(MTL::LoadActionLoad);
  MTL::RenderCommandEncoder *commandEncoder2 = commandBuffer2->renderCommandEncoder(renderPass2);
  renderPass2->release();

  MTL::Viewport viewport;
  viewport.originX = 0.0f;
  viewport.originY = 0.0f;
  viewport.width = framebufferTexture->width();
  viewport.height = framebufferTexture->height();
  viewport.znear = 0.0;
  viewport.zfar = 1.0f;

  commandEncoder2->setRenderPipelineState(debugPipeline);
  commandEncoder2->setFragmentBuffer(debugUBOBuffer, 0, 0);
  commandEncoder2->setFragmentTexture(fb1, 0);
  commandEncoder2->setViewport(viewport);
  commandEncoder2->drawPrimitives(MTL::PrimitiveTypeTriangleStrip, 0, 4, 1);
  commandEncoder2->endEncoding();
  commandEncoder2->release();

  commandBuffer2->presentDrawable(pMetalDrawable);
  static float jake = 0.0f;
  jake += 0.01f;
  jake = (jake > 1.0f) ? 0.0f : jake;
  debug_UBO->darkCol = simd_make_float4(jake, 0.0f, 0.0f, 1.0f);
  commandBuffer2->commit();
  commandBuffer2->release();
}

void MetalDraw::CopyFrameBuffer(MTL::Texture *framebuffer)
{
  /*
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
  */
}
