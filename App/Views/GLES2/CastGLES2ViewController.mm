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

#import "CastGLES2ViewController.h"

#import <algorithm>

#import <GLKit/GLKView.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

#import <GoogleCastRemoteDisplay/GoogleCastRemoteDisplay.h>

#import "CubeRendering.h"

using namespace simd;
using namespace cube_rendering;

namespace {

GLuint LoadProgram(NSString* name, NSArray* bindings) {
  const char* shaderSources[1];
  GLint shaderLengths[1];

  auto vertexSourceUrl = [[NSBundle mainBundle] URLForResource:name withExtension:@"vsh"];
  auto vertexSource = [NSData dataWithContentsOfURL:vertexSourceUrl options:0 error:nullptr];
  GLuint vertexShader = glCreateShader(GL_VERTEX_SHADER);
  shaderSources[0] = (const char*)[vertexSource bytes];
  shaderLengths[0] = (GLint)[vertexSource length];
  glShaderSource(vertexShader, 1, shaderSources, shaderLengths);
  glCompileShader(vertexShader);

  auto fragmentSourceUrl = [[NSBundle mainBundle] URLForResource:name withExtension:@"fsh"];
  auto fragmentSource = [NSData dataWithContentsOfURL:fragmentSourceUrl options:0 error:nullptr];
  GLuint fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
  shaderSources[0] = (const char*)[fragmentSource bytes];
  shaderLengths[0] = (GLint)[fragmentSource length];
  glShaderSource(fragmentShader, 1, shaderSources, shaderLengths);
  glCompileShader(fragmentShader);

  GLuint program = glCreateProgram();
  glAttachShader(program, vertexShader);
  glAttachShader(program, fragmentShader);
  for (GLuint i = 0, end = (GLuint)bindings.count; i < end; ++i) {
    glBindAttribLocation(program, i, [bindings[i] UTF8String]);
  }
  glLinkProgram(program);

  glDeleteShader(vertexShader);
  glDeleteShader(fragmentShader);

  return program;
}

}  // namespace

@implementation CastGLES2ViewController {
  // layer
  BOOL _layerSizeDidUpdate;

  // controller
  int _mvpMatLocation;
  int _normalMatLocation;

  // renderer
  EAGLContext* _context;
  GLuint _vertexBuffer;
  GLuint _vertexArray;
  GLuint _program;

  // common uniforms
  float4x4 _viewMatrix;
  float4x4 _modelviewMatrix;
  float _rotation;

  // uniforms
  float4x4 _projectionMatrix;
  Uniforms _uniforms;

  // CAST
  GCKOpenGLESVideoFrameInput* _castInput;

  GLuint _castBGRATex;
  GLuint _castDepthRb;
  GLuint _castFramebuffer;

  float4x4 _castProjectionMatrix;
  Uniforms _castUniforms;
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];

  [self _setupGLES];
  [self _loadAssets];
}

- (void)viewDidDisappear:(BOOL)animated {
  [(GLKView*)self.view deleteDrawable];
  ((GLKView*)self.view).context = nil;

  [EAGLContext setCurrentContext:_context];

  [self _teardownGLESForCast];

  _rotation = 0;

  glDeleteProgram(_program);
  glDeleteVertexArraysOES(1, &_vertexArray);
  glDeleteBuffers(1, &_vertexBuffer);

  [EAGLContext setCurrentContext:nil];
  _context = nil;

  [super viewDidDisappear:animated];
}

- (void)_setupGLES {
  _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
  [EAGLContext setCurrentContext:_context];
  ((GLKView*)self.view).context = _context;
}

- (void)_loadAssets {
  // Setup the vertex buffers.
  glGenBuffers(1, &_vertexBuffer);
  glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
  glBufferData(GL_ARRAY_BUFFER, sizeof(gCubeVertices), gCubeVertices, GL_STATIC_DRAW);

  glGenVertexArraysOES(1, &_vertexArray);
  glBindVertexArrayOES(_vertexArray);
  glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, sizeof(Vertex), (void*)0);
  glEnableVertexAttribArray(0);
  glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, sizeof(Vertex), (void*)sizeof(Vertex::position));
  glEnableVertexAttribArray(1);

  // Load the lambert shading program.
  _program = LoadProgram(@"Lambert", @[ @"position", @"normal" ]);

  _mvpMatLocation = glGetUniformLocation(_program, "u_mvp_mat");
  _normalMatLocation = glGetUniformLocation(_program, "u_normal_mat");
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
    [EAGLContext setCurrentContext:_context];
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

  _viewMatrix = matrix_identity_float4x4;

  float aspect = std::abs(viewSize.width / viewSize.height);
  _projectionMatrix = matrix_from_perspective(65.0f * (M_PI / 180.0f), aspect, 0.1f, 100.0f);

  // CAST
  if (_castInput) [self _reshapeCast];
}

- (void)_render {
  // CAST
  if (_castInput) [self _syncAndSubmitCastFrame];

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

  // Bind the view drawble.
  GLKView* view = (GLKView*)self.view;
  [view bindDrawable];

  // Configure the render pass.
  glUseProgram(_program);

  glDepthFunc(GL_LESS);
  glDepthMask(GL_TRUE);
  glEnable(GL_DEPTH_TEST);

  glClearColor(0.65f, 0.65f, 0.65f, 1.0f);
  glClearDepthf(1.0f);

  glBindVertexArrayOES(_vertexArray);

  // Upload updated uniforms.
  glUniformMatrix4fv(_mvpMatLocation, 1, GL_FALSE, (GLfloat*)&_uniforms.mvp_mat);
  glUniformMatrix4fv(_normalMatLocation, 1, GL_FALSE, (GLfloat*)&_uniforms.normal_mat);

  // Clear.
  glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

  // Draw.
  glDrawArrays(GL_TRIANGLES, 0, 36);

  // CAST
  if (_castInput) [self _renderCast];
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

  [self _teardownGLESForCast];

  if (castRemoteDisplaySession) [self _prepareGLESForCast:castRemoteDisplaySession];
}

- (void)_prepareGLESForCast:(GCKRemoteDisplaySession*)session {
  _castInput = [[GCKOpenGLESVideoFrameInput alloc] initWithSession:session];
  _castInput.context = _context;

  [self _loadCastAssets];

  _layerSizeDidUpdate = YES;
}

- (void)_loadCastAssets {
  [EAGLContext setCurrentContext:_castInput.context];

  glGenTextures(1, &_castBGRATex);
  glActiveTexture(GL_TEXTURE0);
  glBindTexture(GL_TEXTURE_2D, _castBGRATex);
  glTexStorage2DEXT(GL_TEXTURE_2D, 1, GL_BGRA8_EXT, _castInput.width, _castInput.height);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

  glGenRenderbuffers(1, &_castDepthRb);
  glBindRenderbuffer(GL_RENDERBUFFER, _castDepthRb);
  glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24_OES, _castInput.width,
                        _castInput.height);

  glGenFramebuffers(1, &_castFramebuffer);
  glBindFramebuffer(GL_FRAMEBUFFER, _castFramebuffer);
  glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _castBGRATex, 0);
  glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, _castDepthRb);
}

- (void)_teardownGLESForCast {
  [EAGLContext setCurrentContext:_castInput.context];
  glDeleteTextures(1, &_castBGRATex);
  glDeleteRenderbuffers(1, &_castDepthRb);
  glDeleteFramebuffers(1, &_castFramebuffer);
  _castInput = nil;
}

- (void)_reshapeCast {
  auto width = _castInput.width;
  auto height = _castInput.height;
  float aspect = std::abs(static_cast<float>(width) / static_cast<float>(height));
  _castProjectionMatrix = matrix_from_perspective(65.0f * (M_PI / 180.0f), aspect, 0.1f, 100.0f);
}

- (void)_renderCast {
  // NOTE: This demo app re-uses the program, pipeline and render pass state from the main pass.

  // Bind the view drawble.
  glBindFramebuffer(GL_FRAMEBUFFER, _castFramebuffer);

  // Configure the render pass.
  glViewport(0, 0, _castInput.width, _castInput.height);

  // Upload updated uniforms.
  glUniformMatrix4fv(_mvpMatLocation, 1, GL_FALSE, (GLfloat*)&_castUniforms.mvp_mat);
  glUniformMatrix4fv(_normalMatLocation, 1, GL_FALSE, (GLfloat*)&_castUniforms.normal_mat);

  // Clear.
  glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

  // Draw.
  glDrawArrays(GL_TRIANGLES, 0, 36);

  // Don't store depth buffer data back to main memory.
  GLenum attachments[] = {GL_DEPTH_ATTACHMENT};
  glDiscardFramebufferEXT(GL_FRAMEBUFFER, 1, attachments);

  // Encode frame.
  [_castInput encodeFrame:_castBGRATex];
}

- (void)_syncAndSubmitCastFrame {
  [_castInput syncAndSubmitFrame];
}

@end
