//
//  Copyright (c) Google Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "CastMetalViewController.h"

#import <algorithm>

#import <Metal/Metal.h>
#import <QuartzCore/CADisplayLink.h>
#import <QuartzCore/CAMetalLayer.h>
#import <UIKit/UIKit.h>

#import <GoogleCastRemoteDisplay/GoogleCastRemoteDisplay.h>

#import "CubeRendering.h"

using namespace simd;
using namespace cube_rendering;

namespace {

// The max number of command buffers in flight
const NSUInteger kMaxInflightBuffers = 3;

// Max API memory buffer size.
const size_t kMaxBytesPerFrame = 1024 * 1024;

}  // namespace

@implementation CastMetalViewController {
  // layer
  CAMetalLayer* _metalLayer;
  BOOL _layerSizeDidUpdate;

  // controller
  CADisplayLink* _timer;
  dispatch_semaphore_t _inflight_semaphore;
  id<MTLBuffer> _dynamicConstantBuffer;
  uint8_t _constantDataBufferIndex;

  // renderer
  id<MTLDevice> _device;
  id<MTLCommandQueue> _commandQueue;
  id<MTLLibrary> _defaultLibrary;

  id<MTLRenderPipelineState> _pipelineState;
  id<MTLDepthStencilState> _depthState;

  id<MTLBuffer> _vertexBuffer;
  id<MTLTexture> _depthTex;

  MTLRenderPassDescriptor* _renderPassDescriptor;

  // common uniforms
  float4x4 _viewMatrix;
  float4x4 _modelviewMatrix;
  float _rotation;

  // uniforms
  float4x4 _projectionMatrix;
  Uniforms _uniforms;

  // CAST
  GCKMetalVideoFrameInput* _castInput;

  id<MTLTexture> _castBGRATex;
  id<MTLTexture> _castDepthTex;
  id<MTLRenderPipelineState> _castPipeline;
  MTLRenderPassDescriptor* _castPassDesc;

  float4x4 _castProjectionMatrix;
  Uniforms _castUniforms;
}

- (void)dealloc {
  [_timer invalidate];
}

- (void)viewDidLoad {
  // Setup metal layer and add as sub layer to view.
  _metalLayer = (CAMetalLayer*)self.view.layer;
  _metalLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;
  _metalLayer.presentsWithTransaction = NO;
  _metalLayer.drawsAsynchronously = YES;

  // Change this to NO if the compute encoder is used as the last pass on the drawable texture.
  _metalLayer.framebufferOnly = YES;

  // Finish configuring the view for performance and crispiness.
  self.view.opaque = YES;
  self.view.backgroundColor = nil;
  self.view.contentScaleFactor = [UIScreen mainScreen].scale;

  [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];

  _constantDataBufferIndex = 0;
  _inflight_semaphore = dispatch_semaphore_create(kMaxInflightBuffers);

  [self _setupMetal];
  [self _loadAssets];

  _timer = [CADisplayLink displayLinkWithTarget:self selector:@selector(update)];
  [_timer addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
}

- (void)viewDidDisappear:(BOOL)animated {
  [_timer invalidate];
  _metalLayer.device = nil;

  dispatch_semaphore_signal(_inflight_semaphore);
  dispatch_semaphore_signal(_inflight_semaphore);
  dispatch_semaphore_signal(_inflight_semaphore);

  [self _teardownMetalForCast];

  _rotation = 0;

  _depthTex = nil;
  _depthState = nil;
  _vertexBuffer = nil;
  _pipelineState = nil;
  _defaultLibrary = nil;
  _commandQueue = nil;
  _device = nil;

  _dynamicConstantBuffer = nil;
  _inflight_semaphore = nil;
  _timer = nil;

  _renderPassDescriptor = nil;

  [super viewDidDisappear:animated];
}

- (void)_setupMetal {
  _device = MTLCreateSystemDefaultDevice();
  _commandQueue = [_device newCommandQueue];
  _defaultLibrary = [_device newDefaultLibrary];
  _metalLayer.device = _device;
}

- (void)_loadAssets {
  // Allocate one region of memory for the uniform buffer.
  _dynamicConstantBuffer = [_device newBufferWithLength:kMaxBytesPerFrame options:0];

  // Setup the vertex buffers.
  _vertexBuffer = [_device newBufferWithBytes:gCubeVertices
                                       length:sizeof(gCubeVertices)
                                      options:MTLResourceOptionCPUCacheModeDefault];

  // Load the Lambert lighting functions from the default library.
  auto vertexFunction = [_defaultLibrary newFunctionWithName:@"lambert_vertex"];
  auto fragmentFunction = [_defaultLibrary newFunctionWithName:@"lambert_fragment"];

  // Reusable pipeline state.
  auto pipelineDesc = [MTLRenderPipelineDescriptor new];
  pipelineDesc.vertexFunction = vertexFunction;
  pipelineDesc.fragmentFunction = fragmentFunction;
  pipelineDesc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
  pipelineDesc.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float;

  NSError* error = NULL;
  _pipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineDesc error:&error];
  if (!_pipelineState) {
    NSLog(@"Failed to created pipeline state, error %@", error);
  }

  // Reusable depth state.
  auto depthStateDesc = [[MTLDepthStencilDescriptor alloc] init];
  depthStateDesc.depthCompareFunction = MTLCompareFunctionLess;
  depthStateDesc.depthWriteEnabled = YES;
  _depthState = [_device newDepthStencilStateWithDescriptor:depthStateDesc];

  // Reusable render pass descriptor.
  _renderPassDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];

  _renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
  _renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
  _renderPassDescriptor.colorAttachments[0].clearColor = {0.65f, 0.65f, 0.65f, 1.0f};

  _renderPassDescriptor.depthAttachment.loadAction = MTLLoadActionClear;
  _renderPassDescriptor.depthAttachment.storeAction = MTLStoreActionDontCare;
  _renderPassDescriptor.depthAttachment.clearDepth = 1.0f;
}

- (BOOL)prefersStatusBarHidden {
  return YES;
}

- (void)viewDidLayoutSubviews {
  _layerSizeDidUpdate = YES;
  [super viewDidLayoutSubviews];
}

- (void)update {
  @autoreleasepool {
    if (_layerSizeDidUpdate) {
      [self _reshape];
      _layerSizeDidUpdate = NO;
    }
    [self _render];
  }
}

- (void)_reshape {
  auto view = self.view;
  auto viewSize = view.bounds.size;
  auto viewScale = view.window.screen.nativeScale;

  auto surfaceSize = CGSize{viewSize.width * viewScale, viewSize.height * viewScale};
  _metalLayer.drawableSize = surfaceSize;

  _viewMatrix = matrix_identity_float4x4;

  float aspect = std::abs(viewSize.width / viewSize.height);
  _projectionMatrix = matrix_from_perspective(65.0f * (M_PI / 180.0f), aspect, 0.1f, 100.0f);

  auto surfaceSizeMtl = MTLSizeMake(surfaceSize.width, surfaceSize.height, 1);
  if (_depthTex.width != surfaceSizeMtl.width || _depthTex.height != surfaceSizeMtl.height) {
    auto desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatDepth32Float
                                                                   width:surfaceSizeMtl.width
                                                                  height:surfaceSizeMtl.height
                                                               mipmapped:NO];
    _depthTex = [_device newTextureWithDescriptor:desc];
    _renderPassDescriptor.depthAttachment.texture = _depthTex;
  }

  // CAST
  if (_castInput) [self _reshapeCast];
}

- (void)_render {
  // Update the scene.
  [self _animate];

  // Update uniforms.
  _uniforms.mvp_mat = _projectionMatrix * _modelviewMatrix;
  _uniforms.normal_mat = inverse(transpose(_modelviewMatrix));

  // CAST
  if (_castInput) {
    _castUniforms.mvp_mat = _castProjectionMatrix * _modelviewMatrix;
    _castUniforms.normal_mat = _uniforms.normal_mat;
  }

  // Block until we have a constants buffer slot available.
  dispatch_semaphore_wait(_inflight_semaphore, DISPATCH_TIME_FOREVER);

  // Obtain a drawable texture for this render pass. This can fail if there are no drawables
  // available (ex: we're drawing too fast) or we don't have access to the screen (backgrounding).
  id<CAMetalDrawable> drawable = [_metalLayer nextDrawable];
  if (!drawable) {
    NSLog(@"No drawable from layer, dropping frame.");
    dispatch_semaphore_signal(_inflight_semaphore);
    return;
  }

  // Load constant buffer data into appropriate buffer at current index.
  Uniforms* uniformsBuffer = reinterpret_cast<Uniforms*>([_dynamicConstantBuffer contents]);
  memcpy(uniformsBuffer + _constantDataBufferIndex, &_uniforms, sizeof(_uniforms));

  // Create a new command buffer for this frame.
  auto commandBuffer = [_commandQueue commandBuffer];

  // Update the render pass descriptor with the current drawable texture.
  _renderPassDescriptor.colorAttachments[0].texture = drawable.texture;

  // Render the cube.
  NSUInteger constantsOffset = sizeof(Uniforms) * _constantDataBufferIndex;
  auto renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:_renderPassDescriptor];
  [renderEncoder setRenderPipelineState:_pipelineState];
  [renderEncoder setDepthStencilState:_depthState];
  [renderEncoder setVertexBuffer:_vertexBuffer offset:0 atIndex:0];
  [renderEncoder setVertexBuffer:_dynamicConstantBuffer offset:constantsOffset atIndex:1];
  [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:36];
  [renderEncoder endEncoding];

  // Screen drawable is ready for present.
  [commandBuffer presentDrawable:drawable];

  // CAST
  if (_castInput) [self _renderCast:commandBuffer];

  // When the command buffer completes, signal the inflight semaphore to indicate we have buffer
  // space available for another frame.
  __block dispatch_semaphore_t block_sema = _inflight_semaphore;
  [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer) {
    dispatch_semaphore_signal(block_sema);
  }];

  // Increment the constants buffer index. It is not used until the inflight semaphore says we can.
  _constantDataBufferIndex = (_constantDataBufferIndex + 1) % kMaxInflightBuffers;

  // Commit the command buffer for execution.
  [commandBuffer commit];
}

- (void)_animate {
  auto model = matrix_from_translation(0.0f, 0.0f, 5.0f) *
               matrix_from_rotation(_rotation, 0.0f, 1.0f, 0.0f) *
               matrix_from_rotation(_rotation, 1.0f, 1.0f, 1.0f);
  _modelviewMatrix = _viewMatrix * model;
  _rotation += 0.01f;
}

#pragma mark CAST

@dynamic castRemoteDisplaySession;

- (GCKRemoteDisplaySession*)castRemoteDisplaySession {
  return _castInput.session;
}

- (void)setCastRemoteDisplaySession:(GCKRemoteDisplaySession*)castRemoteDisplaySession {
  if (castRemoteDisplaySession == _castInput.session) return;

  [self _teardownMetalForCast];

  if (castRemoteDisplaySession) [self _prepareMetalForCast:castRemoteDisplaySession];
}

- (void)_prepareMetalForCast:(GCKRemoteDisplaySession*)session {
  _castInput = [[GCKMetalVideoFrameInput alloc] initWithSession:session];
  _castInput.device = _device;

  [self _loadCastAssets];

  _layerSizeDidUpdate = YES;
}

- (void)_loadCastAssets {
  NSError* error = NULL;

  auto videoWidth = _castInput.width;
  auto videoHeight = _castInput.height;

  auto texDesc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm
                                                                    width:videoWidth
                                                                   height:videoHeight
                                                                mipmapped:NO];
  _castBGRATex = [_device newTextureWithDescriptor:texDesc];

  texDesc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatDepth32Float
                                                               width:videoWidth
                                                              height:videoHeight
                                                           mipmapped:NO];
  _castDepthTex = [_device newTextureWithDescriptor:texDesc];

  auto vertexFunction = [_defaultLibrary newFunctionWithName:@"lambert_vertex"];
  auto fragmentFunction = [_defaultLibrary newFunctionWithName:@"lambert_fragment"];

  auto pipelineDesc = [MTLRenderPipelineDescriptor new];
  pipelineDesc.vertexFunction = vertexFunction;
  pipelineDesc.fragmentFunction = fragmentFunction;
  pipelineDesc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
  pipelineDesc.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float;

  _castPipeline = [_device newRenderPipelineStateWithDescriptor:pipelineDesc error:&error];
  if (!_castPipeline) {
    NSLog(@"Failed to created cast main pass pipeline state: %@", error);
    return;
  }

  _castPassDesc = [_renderPassDescriptor copy];
  _castPassDesc.colorAttachments[0].texture = _castBGRATex;
  _castPassDesc.depthAttachment.texture = _castDepthTex;
}

- (void)_teardownMetalForCast {
  _castInput = nil;
  _castBGRATex = nil;
  _castDepthTex = nil;
  _castPipeline = nil;
  _castPassDesc = nil;
}

- (void)_reshapeCast {
  auto width = _castInput.width;
  auto height = _castInput.height;
  float aspect = std::abs(static_cast<float>(width) / static_cast<float>(height));
  _castProjectionMatrix = matrix_from_perspective(65.0f * (M_PI / 180.0f), aspect, 0.1f, 100.0f);
}

- (void)_renderCast:(id<MTLCommandBuffer>)commandBuffer {
  // The Cast input holds the session weakly. If the session is nil, tear down.
  if (!_castInput.session) {
    [self _teardownMetalForCast];
    return;
  }

  // Load constants buffer data at the index for this frame. Offset by kMaxInflightBuffers to not
  // overwrite main pass constants.
  auto constantsIndex = kMaxInflightBuffers + _constantDataBufferIndex;
  NSUInteger constantsOffset = sizeof(Uniforms) * constantsIndex;

  Uniforms* uniformsBuffer = reinterpret_cast<Uniforms*>([_dynamicConstantBuffer contents]);
  memcpy(uniformsBuffer + constantsIndex, &_castUniforms, sizeof(_castUniforms));

  // Render the cube to Cast.
  auto renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:_castPassDesc];
  [renderEncoder setRenderPipelineState:_castPipeline];
  [renderEncoder setDepthStencilState:_depthState];
  [renderEncoder setVertexBuffer:_vertexBuffer offset:0 atIndex:0];
  [renderEncoder setVertexBuffer:_dynamicConstantBuffer offset:constantsOffset atIndex:1];
  [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:36];
  [renderEncoder endEncoding];

  // Encode the cast texture for processing, encoding and transmission.
  [_castInput encodeFrame:_castBGRATex commandBuffer:commandBuffer];
}

@end
