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

const vec3 light_position = vec3(0.0, 1.0, -1.0);
const vec4 ambient_color  = vec4(0.18, 0.24, 0.8, 1.0);
const vec4 diffuse_color  = vec4(0.4, 0.4, 1.0, 1.0);

attribute vec3 position;
attribute vec3 normal;

varying lowp vec4 v_color;

uniform mat4 u_mvp_mat;
uniform mat4 u_normal_mat;

void main() {
  gl_Position = u_mvp_mat * vec4(position, 1.0);

  vec4 eye_normal = normalize(u_normal_mat * vec4(normal, 0.0));
  float n_dot_l = dot(eye_normal.xyz, normalize(light_position));
  n_dot_l = max(0.0, n_dot_l);

  v_color = vec4(ambient_color + diffuse_color * n_dot_l);
}
