//
//  MetalDraw.hpp
//  MetalTriangleCPP
//
//  Created by Jake on 10/12/2021.
//  Copyright © 2021 Apple. All rights reserved.
//

#pragma once

#include "official/metal/MetalCPP.h"

struct MetalDraw
{
  void Loaded(NS::String *defaultLibraryPath, NS::Data *defaultLibraryData);
  void BuildDevice();
  void BuildVertexBuffers();
  void BuildPipeline(NS::String *defaultLibraryPath, NS::Data *defaultLibraryData);
  
  void Draw(CA::MetalDrawable *pMetalDrawable);
  void CopyFrameBuffer(MTL::Texture *framebuffer);

  MTL::Device *device;
  MTL::RenderPipelineState *pipeline;
  MTL::CommandQueue *commandQueue;
  MTL::Buffer *positionBuffer;
  MTL::Buffer *colorBuffer;

  MTL::RenderPipelineState *debugPipeline;
  MTL::Buffer *debugUBOBuffer;

  MTL::Texture *fb1;
};

MetalDraw *CreateMetalDraw();
