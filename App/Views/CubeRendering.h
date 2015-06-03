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

#include <simd/simd.h>

/**
 *  Namespace to contain the data points for rendering a cube.
 */
namespace cube_rendering {

  struct Uniforms {
    simd::float4x4 mvp_mat;
    simd::float4x4 normal_mat;
    simd::float4 ambient_color;
  };

  struct Vertex {
    float position[3];
    float normal[3];
  } __attribute__((__packed__));
  static_assert(sizeof(Vertex) == 6 * sizeof(float), "Vertex is not packed");

  extern const Vertex gCubeVertices[36];

  extern simd::float4x4 matrix_from_perspective(float fovY, float aspect, float nearZ, float farZ);
  extern simd::float4x4 matrix_from_translation(float x, float y, float z);
  extern simd::float4x4 matrix_from_rotation(float radians, float x, float y, float z);

}  // namespace cube_rendering
