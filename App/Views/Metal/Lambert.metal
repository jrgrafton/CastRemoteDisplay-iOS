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

#include <metal_stdlib>

using namespace metal;

constant float3 light_position = float3(0.0, 1.0, -1.0);
constant float4 ambient_color  = float4(0.8, 0.24, 0.18, 1.0);
constant float4 diffuse_color  = float4(1.0, 0.4, 0.4, 1.0);

struct Uniforms {
  float4x4 mvp_mat;
  float4x4 normal_mat;
};

struct Vertex {
  packed_float3 position;
  packed_float3 normal;
};

struct Lambert {
  float4 position [[ position ]];
  half4  color;
};

vertex Lambert lambert_vertex(
    device   Vertex*   vertex_array [[ buffer(0) ]],
    constant Uniforms& uniforms     [[ buffer(1) ]],
    uint               vid          [[ vertex_id ]]) {
  Lambert out;

  float4 in_position = float4(float3(vertex_array[vid].position), 1.0);
  out.position = uniforms.mvp_mat * in_position;

  float3 normal = vertex_array[vid].normal;
  float4 eye_normal = normalize(uniforms.normal_mat * float4(normal, 0.0));
  float n_dot_l = fmax(0.0, dot(eye_normal.rgb, normalize(light_position)));

  out.color = half4(ambient_color + diffuse_color * n_dot_l);

  return out;
}

fragment half4 lambert_fragment(Lambert in [[ stage_in ]]) {
  return in.color;
}
