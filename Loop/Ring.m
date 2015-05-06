// Copyright Google Inc.
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

#import "Ring.h"

#import <GLKit/GLKit.h>

@interface Ring () {
  const char *_vertexShaderSourceCString;
  const char *_fragmentShaderSourceCString;
}
@end

@implementation Ring

- (instancetype) init {
  self = [super init];
  if (self) {
  }
  return self;
}

- (void)setup {
  NSString *vertexShaderSource =
  [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"VertexShader"
                                                                     ofType:@"vsh"]
                            encoding:NSUTF8StringEncoding
                               error:nil];
  _vertexShaderSourceCString = [vertexShaderSource cStringUsingEncoding:NSUTF8StringEncoding];
  NSString *fragmentShaderSource = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"FragmentShader" ofType:@"fsh"] encoding:NSUTF8StringEncoding error:nil];
  _fragmentShaderSourceCString = [fragmentShaderSource cStringUsingEncoding:NSUTF8StringEncoding];

  GLuint vertexShader = glCreateShader(GL_VERTEX_SHADER);
  glShaderSource(vertexShader, 1, &_vertexShaderSourceCString, NULL);
  glCompileShader(vertexShader);

  GLuint fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
  glShaderSource(fragmentShader, 1, &_fragmentShaderSourceCString, NULL);
  glCompileShader(fragmentShader);

  GLuint program = glCreateProgram();
  glAttachShader(program, vertexShader);
  glAttachShader(program, fragmentShader);
  glLinkProgram(program);
  glUseProgram(program);

  GLfloat square[] = {
    -0.5, -0.5,
    0.5, -0.5,
    -0.5, 0.5,
    0.5, 0.5};

  const char *aPositionCString = [@"a_position" cStringUsingEncoding:NSUTF8StringEncoding];
  GLuint aPosition = glGetAttribLocation(program, aPositionCString);
  glVertexAttribPointer(aPosition, 2, GL_FLOAT, GL_FALSE, 0, square);
  glEnableVertexAttribArray(aPosition);

}

- (void)draw {
  glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}

@end
