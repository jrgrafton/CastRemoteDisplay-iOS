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

#include "CubeRendering.h"

namespace cube_rendering {

const Vertex gCubeVertices[36] = {
  {{ 0.5, -0.5,  0.5}, { 0.0, -1.0,  0.0}},
  {{-0.5, -0.5,  0.5}, { 0.0, -1.0,  0.0}},
  {{-0.5, -0.5, -0.5}, { 0.0, -1.0,  0.0}},
  {{ 0.5, -0.5, -0.5}, { 0.0, -1.0,  0.0}},
  {{ 0.5, -0.5,  0.5}, { 0.0, -1.0,  0.0}},
  {{-0.5, -0.5, -0.5}, { 0.0, -1.0,  0.0}},

  {{ 0.5,  0.5,  0.5}, { 1.0,  0.0,  0.0}},
  {{ 0.5, -0.5,  0.5}, { 1.0,  0.0,  0.0}},
  {{ 0.5, -0.5, -0.5}, { 1.0,  0.0,  0.0}},
  {{ 0.5,  0.5, -0.5}, { 1.0,  0.0,  0.0}},
  {{ 0.5,  0.5,  0.5}, { 1.0,  0.0,  0.0}},
  {{ 0.5, -0.5, -0.5}, { 1.0,  0.0,  0.0}},

  {{-0.5,  0.5,  0.5}, { 0.0,  1.0,  0.0}},
  {{ 0.5,  0.5,  0.5}, { 0.0,  1.0,  0.0}},
  {{ 0.5,  0.5, -0.5}, { 0.0,  1.0,  0.0}},
  {{-0.5,  0.5, -0.5}, { 0.0,  1.0,  0.0}},
  {{-0.5,  0.5,  0.5}, { 0.0,  1.0,  0.0}},
  {{ 0.5,  0.5, -0.5}, { 0.0,  1.0,  0.0}},

  {{-0.5, -0.5,  0.5}, {-1.0,  0.0,  0.0}},
  {{-0.5,  0.5,  0.5}, {-1.0,  0.0,  0.0}},
  {{-0.5,  0.5, -0.5}, {-1.0,  0.0,  0.0}},
  {{-0.5, -0.5, -0.5}, {-1.0,  0.0,  0.0}},
  {{-0.5, -0.5,  0.5}, {-1.0,  0.0,  0.0}},
  {{-0.5,  0.5, -0.5}, {-1.0,  0.0,  0.0}},

  {{ 0.5,  0.5,  0.5}, { 0.0,  0.0,  1.0}},
  {{-0.5,  0.5,  0.5}, { 0.0,  0.0,  1.0}},
  {{-0.5, -0.5,  0.5}, { 0.0,  0.0,  1.0}},
  {{-0.5, -0.5,  0.5}, { 0.0,  0.0,  1.0}},
  {{ 0.5, -0.5,  0.5}, { 0.0,  0.0,  1.0}},
  {{ 0.5,  0.5,  0.5}, { 0.0,  0.0,  1.0}},

  {{ 0.5, -0.5, -0.5}, { 0.0,  0.0, -1.0}},
  {{-0.5, -0.5, -0.5}, { 0.0,  0.0, -1.0}},
  {{-0.5,  0.5, -0.5}, { 0.0,  0.0, -1.0}},
  {{ 0.5,  0.5, -0.5}, { 0.0,  0.0, -1.0}},
  {{ 0.5, -0.5, -0.5}, { 0.0,  0.0, -1.0}},
  {{-0.5,  0.5, -0.5}, { 0.0,  0.0, -1.0}}
};

simd::float4x4 matrix_from_perspective(float fovY, float aspect, float nearZ, float farZ) {
  float yscale = 1.0f / tanf(fovY * 0.5f);  // 1 / tan == cot
  float xscale = yscale / aspect;
  float q = farZ / (farZ - nearZ);

  simd::float4x4 m = {simd::float4{xscale, 0.0f, 0.0f, 0.0f},
                      simd::float4{0.0f, yscale, 0.0f, 0.0f}, simd::float4{0.0f, 0.0f, q, 1.0f},
                      simd::float4{0.0f, 0.0f, q * -nearZ, 0.0f}};

  return m;
}

simd::float4x4 matrix_from_translation(float x, float y, float z) {
  simd::float4x4 m = matrix_identity_float4x4;
  m.columns[3] = {x, y, z, 1.0};
  return m;
}

simd::float4x4 matrix_from_rotation(float radians, float x, float y, float z) {
  simd::float3 v = simd::normalize(simd::float3{x, y, z});
  float cos = cosf(radians);
  float cosp = 1.0f - cos;
  float sin = sinf(radians);
  return simd::float4x4{simd::float4{cos + cosp * v.x * v.x, cosp * v.x * v.y + v.z * sin,
                                     cosp * v.x * v.z - v.y * sin, 0.0f},
                        simd::float4{cosp * v.x * v.y - v.z * sin, cos + cosp * v.y * v.y,
                                     cosp * v.y * v.z + v.x * sin, 0.0f},
                        simd::float4{cosp * v.x * v.z + v.y * sin, cosp * v.y * v.z - v.x * sin,
                                     cos + cosp * v.z * v.z, 0.0f},
                        simd::float4{0.0f, 0.0f, 0.0f, 1.0f}};
}

}  //  cube_rendering
