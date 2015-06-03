//
// Copyright 2015 Google Inc. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
#import "CastGLES2ViewController.h"
#import "CubeRendering.h"

#import <GLKit/GLKit.h>
#import <GoogleCastRemoteDisplay/GoogleCastRemoteDisplay.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import <algorithm>

using namespace simd;
using namespace cube_rendering;

namespace {

/**
 *  Load and compile a vertext and fragment shader, and return a GL program.
 *
 *  @param name     String shader file name
 *  @param bindings Attributes to bind - values for the shader.
 *
 *  @return GLprogram representing the shader
 */
GLuint LoadProgram(NSString* name, NSDictionary* bindings) {
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
  for (NSNumber *key in bindings) {
    glBindAttribLocation(program, [key unsignedIntValue], [bindings[key] UTF8String]);
  }
  glLinkProgram(program);

  glDeleteShader(vertexShader);
  glDeleteShader(fragmentShader);

  return program;
}

}  // namespace


/**
 *  The OpenGL ES Cast renderer. Displays a 3d spinning cube on the Cast remote display,
 *  and a simple output on the local display. See the Cast Rendering mark for the Cast specific
 *  code.
 */
@implementation CastGLES2ViewController {
  // Has the layer sized changed.
  BOOL _layerSizeDidUpdate;
  // Has the default color changed.
  BOOL _colorChanged;

  // Controller
  int _mvpMatLocation;
  int _normalMatLocation;
  int _ambientColorLocation;

  // Renderer
  GLuint _vertexBuffer;
  GLuint _vertexArray;
  GLuint _program;
  GLuint _textureBGRA;
  GLuint _depthRenderBuffer;
  GLuint _frameBuffer;

  // Uniforms
  Uniforms _uniforms;
  float4x4 _projectionMatrix;
  float4x4 _viewMatrix;
  float4x4 _modelviewMatrix;
  float _rotation;

  // The Cast frame input for OpenGL ES. This is used to send data to be displayed remotely.
  GCKOpenGLESVideoFrameInput* _castInput;

  // Context and image for local display.
  EAGLContext* _context;
  CIContext *_cicontext;
  CIImage *_bgImage;
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];

  // Setup the basic GLES context.
  [self setupGLESContext];

  // Load the GL assets for local usage.
  [self loadAssets];

  // Prepare for Cast if we have a session.
  if (self.castRemoteDisplaySession) {
    [self prepareGLESForCast:self.castRemoteDisplaySession];
  }
}

- (void)viewDidDisappear:(BOOL)animated {
  [(GLKView*)self.view deleteDrawable];
  ((GLKView*)self.view).context = nil;

  [self teardownGLESForCast];
  [self teardownGLESLocal];

  [super viewDidDisappear:animated];
}

- (BOOL)prefersStatusBarHidden {
  return YES;
}

- (void)viewDidLayoutSubviews {
  _layerSizeDidUpdate = YES;
  [super viewDidLayoutSubviews];
}


- (IBAction)didTapChangeColor:(id)sender {
  _colorChanged = !_colorChanged;
}

# pragma mark - OpenGL

/**
 *  Setup the basic OpenGLES environment.
 */
- (void)setupGLESContext {
  _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
  [EAGLContext setCurrentContext:_context];
  ((GLKView*)self.view).context = _context;
}

- (void)teardownGLESLocal {
  [EAGLContext setCurrentContext:nil];
  _context = nil;
}

/**
 *  Update the state of the display - this is called automatically by GLKViewController.
 */
- (void)update {
  @autoreleasepool {
    if (_layerSizeDidUpdate) {
      [self reshape];
      _layerSizeDidUpdate = NO;
    }
    [self render];
  }
}

/**
 *  Resize the view based on the dimensions changing - e.g. on rotation.
 */
- (void)reshape {
  // Resize cast input if necessary.
  if (_castInput) {
    [self reshapeCast];
  }
}

/**
 *  Setup the basic 3d environment for first screen.
 */
- (void)loadAssets {
  UIImage *background = [UIImage imageNamed:@"background"];
  _bgImage = [CIImage imageWithCGImage:background.CGImage];
  _cicontext = [CIContext contextWithEAGLContext:_context
                                         options:@{kCIContextWorkingColorSpace : [NSNull null]} ];
}

/**
 *  Main render function. Updates the local display, and renders the spinning cube for the
 *  Cast remote display.
 */
- (void)render {
  [EAGLContext setCurrentContext:_context];

  // Bind the view drawble.
  GLKView* view = (GLKView*)self.view;
  [view bindDrawable];

  // Scale the image up to the pixel size required.
  float scale = [UIScreen mainScreen].scale;
  CGRect destRect = CGRectApplyAffineTransform(self.view.bounds,
                                               CGAffineTransformMakeScale(scale, scale));
  // Render the image.
  [_cicontext drawImage:_bgImage
                 inRect:destRect
               fromRect:[_bgImage extent]];

  // Update the Cast display.
  if (_castInput) {
    [self renderCast];
  }
}

#pragma mark castRemoteDisplaySession

- (GCKRemoteDisplaySession*)castRemoteDisplaySession {
  return _castInput.session;
}

- (void)setCastRemoteDisplaySession:(GCKRemoteDisplaySession*)castRemoteDisplaySession {
  if (castRemoteDisplaySession == _castInput.session) {
    return;
  }

  if (_castInput) {
    [self teardownGLESForCast];
  }

  if (castRemoteDisplaySession) {
    [self prepareGLESForCast:castRemoteDisplaySession];
  }
}

# pragma mark - Cast Rendering

/**
 *  Setup the GL environment for Cast remote display output.
 *
 *  @param session A connected Cast Remote Display session.
 */
- (void)prepareGLESForCast:(GCKRemoteDisplaySession*)session {
  _castInput = [[GCKOpenGLESVideoFrameInput alloc] initWithSession:session];
  _castInput.context = _context;

  [self loadCastAssets];

  _layerSizeDidUpdate = YES;
}

/**
 *  Prepare buffers for the Cast display. We set the GL context to the Cast input, and then
 *  issue regular gl* commands.
 */
- (void)loadCastAssets {
  [EAGLContext setCurrentContext:_castInput.context];

  glGenBuffers(1, &_vertexBuffer);
  glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
  glBufferData(GL_ARRAY_BUFFER, sizeof(gCubeVertices), gCubeVertices, GL_STATIC_DRAW);

  glGenVertexArraysOES(1, &_vertexArray);
  glBindVertexArrayOES(_vertexArray);

  glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(Vertex), (void*)0);
  glEnableVertexAttribArray(GLKVertexAttribPosition);
  glVertexAttribPointer(GLKVertexAttribNormal, 3, GL_FLOAT, GL_FALSE, sizeof(Vertex),
                        (void*)sizeof(Vertex::position));
  glEnableVertexAttribArray(GLKVertexAttribNormal);

  // Load the lambert shading program.
  _program = LoadProgram(@"Lambert", @{@(GLKVertexAttribPosition): @"position",
                                       @(GLKVertexAttribNormal): @"normal"});

  _mvpMatLocation = glGetUniformLocation(_program, "u_mvp_mat");
  _normalMatLocation = glGetUniformLocation(_program, "u_normal_mat");
  _ambientColorLocation = glGetUniformLocation(_program, "u_ambient_color");

  glGenTextures(1, &_textureBGRA);
  glActiveTexture(GL_TEXTURE0);
  glBindTexture(GL_TEXTURE_2D, _textureBGRA);
  glTexStorage2DEXT(GL_TEXTURE_2D, 1, GL_BGRA8_EXT, _castInput.width, _castInput.height);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

  glGenRenderbuffers(1, &_depthRenderBuffer);
  glBindRenderbuffer(GL_RENDERBUFFER, _depthRenderBuffer);
  glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24_OES, _castInput.width,
                        _castInput.height);

  glGenFramebuffers(1, &_frameBuffer);
  glBindFramebuffer(GL_FRAMEBUFFER, _frameBuffer);
  glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _textureBGRA, 0);
  glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, _depthRenderBuffer);
}

/**
 *  Update the rendering of the cube for the Cast display.
 */
- (void)renderCast {
  // This sample app takes the strategy of calling syncAndSubmitCastFrame at the beginning of each
  // frame to submit the previously encoded frame. This introduces a one frame delay (at least)
  // between local rendering and what is displayed on the remote screen, but also minimizes the
  // chance of blocking the CPU waiting for the GPU to finish processing the last frame.
  [self syncAndSubmitCastFrame];

  // Update the scene.
  [self animateCube];

  // Update uniforms.
  _uniforms.mvp_mat = _projectionMatrix * _modelviewMatrix;
  _uniforms.normal_mat = inverse(transpose(_modelviewMatrix));
  // Set the color.
  if (_colorChanged) {
    _uniforms.ambient_color = {0.24, 0.18, 0.8, 1.0};
  } else {
    _uniforms.ambient_color = {0.24, 0.8, 0.18, 1.0};
  }

  // Bind the view drawble.
  glBindFramebuffer(GL_FRAMEBUFFER, _frameBuffer);

  // Configure the render pass.
  glViewport(0, 0, _castInput.width, _castInput.height);

  // Use the shader.
  glUseProgram(_program);

  glDepthFunc(GL_LESS);
  glDepthMask(GL_TRUE);
  glEnable(GL_DEPTH_TEST);

  // Clear the cast display to a mid grey.
  glClearColor(0.65f, 0.65f, 0.65f, 1.0f);

  // Upload updated uniforms.
  glUniformMatrix4fv(_mvpMatLocation, 1, GL_FALSE, (GLfloat*)&_uniforms.mvp_mat);
  glUniformMatrix4fv(_normalMatLocation, 1, GL_FALSE, (GLfloat*)&_uniforms.normal_mat);
  glUniform4fv(_ambientColorLocation, 1, (GLfloat*)&_uniforms.ambient_color);

  // Bind the vertex arrays for drawing a cube.
  glBindVertexArrayOES(_vertexArray);

  // Clear.
  glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

  // Draw.
  glDrawArrays(GL_TRIANGLES, 0, 36);

  // Don't store depth buffer data back to main memory.
  GLenum attachments[] = {GL_DEPTH_ATTACHMENT};
  glDiscardFramebufferEXT(GL_FRAMEBUFFER, 1, attachments);

  // Encode frame.
  [_castInput encodeFrame:_textureBGRA];
}

/**
 *  Rotate the modelviewMatrix for the cube.
 */
- (void)animateCube {
  auto model = matrix_from_translation(0.0f, 0.0f, 5.0f) *
  matrix_from_rotation(_rotation, 0.0f, 1.0f, 0.0f) *
  matrix_from_rotation(_rotation, 1.0f, 1.0f, 1.0f);
  _modelviewMatrix = _viewMatrix * model;
  _rotation += 0.01f;
}

/**
 *  Clean up the GL environment used for the Cast screen rendering.
 */
- (void)teardownGLESForCast {
  [EAGLContext setCurrentContext:_castInput.context];
  glDeleteTextures(1, &_textureBGRA);
  glDeleteRenderbuffers(1, &_depthRenderBuffer);
  glDeleteFramebuffers(1, &_frameBuffer);
  glDeleteProgram(_program);
  glDeleteVertexArraysOES(1, &_vertexArray);
  glDeleteBuffers(1, &_vertexBuffer);
  _rotation = 0;
  _castInput = nil;
}

/**
 *  Update the projection based on the dimensions of the Cast screen rendering.
 */
- (void)reshapeCast {
  _viewMatrix = matrix_identity_float4x4;
  auto width = _castInput.width;
  auto height = _castInput.height;
  float aspect = std::abs(static_cast<float>(width) / static_cast<float>(height));
  _projectionMatrix = matrix_from_perspective(65.0f * (M_PI / 180.0f), aspect, 0.1f, 100.0f);
}


/**
 *  Wait for the GPU to be done processing the last frame encoded by the frame input and submit
 *  the frame for transmission to the remote display.
 */
- (void)syncAndSubmitCastFrame {
  [_castInput syncAndSubmitFrame];
}

@end
