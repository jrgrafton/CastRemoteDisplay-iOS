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
#import "Tunnel.h"

static const NSInteger kMaxRings = 14;
static const float kNodeGap = 4.0f;

@interface Tunnel ()

@property (nonatomic) NSMutableArray *rings;

@end

@implementation Tunnel

- (void)setup {
  self.rings = [[NSMutableArray alloc] initWithCapacity:kMaxRings];
  for (NSInteger i = 0; i < kMaxRings; i++) {
    Ring *ring = [[Ring alloc] init];
    [ring setup];
    ring.zPos = i * kNodeGap;
    _rings[i] = ring;
  }
}

- (void)draw {

}

@end
