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

#import "BeatControl.h"

@interface BeatControl ()

@property (nonatomic) NSMutableDictionary *tickLayers;

@end

@implementation BeatControl

//TODO(ianbarber) IMplement IBDrawable.

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
  self = [super initWithCoder:aDecoder];
  if (self) {
    [self addTickLayers];
  }
  return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    [self addTickLayers];
  }
  return self;
}

- (void)drawRect:(CGRect)rect{
  [super drawRect:rect];
}

- (void)addTickLayers {
  self.tickLayers = [NSMutableDictionary dictionaryWithCapacity:16];
  float Cx = self.frame.size.width/2;
  float Cy = self.frame.size.width/2;
  int radius = self.frame.size.width/2;
  UIBezierPath *bigTick = [UIBezierPath bezierPath];
  [bigTick moveToPoint:CGPointMake(0, 15)];
  [bigTick addLineToPoint:CGPointMake(20, 15)];
  UIBezierPath *smallTick = [UIBezierPath bezierPath];
  [smallTick moveToPoint:CGPointMake(0, 15)];
  [smallTick addLineToPoint:CGPointMake(10, 15)];
  for (int position=0; position <16; position ++) {
    int tick = (position + 4) % 16;
    float theta = tick * 0.125 * M_PI;

    float X = Cx + radius * cos(theta);
    float Y = Cy + radius * sin(theta);

    CGRect frame = CGRectIntegral(CGRectMake(X-20, Y-20, 30, 30));

    CAShapeLayer *shapeLayer = [CAShapeLayer layer];
    shapeLayer.frame = frame;
    if (tick % 4 == 0) {
      shapeLayer.path = [bigTick CGPath];
    } else {
      shapeLayer.path = [smallTick CGPath];
    }
    // TODO: Constants for colours.
    shapeLayer.strokeColor = [[UIColor blackColor] CGColor];
    shapeLayer.lineWidth = 3.0;
    shapeLayer.fillColor = [[UIColor clearColor] CGColor];
    if (tick > 0) {
      // TOOD(ianbarber): Replace magic number with constant for 360/16 / 180)
      shapeLayer.transform = CATransform3DMakeRotation(tick * 0.125 * M_PI, 0.0, 0.0, 1.0);
    }

    [_tickLayers setObject:shapeLayer forKey:@((position + 8) % 16)];
    [self.layer addSublayer:shapeLayer];
  }
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
  for (NSNumber *key in _tickLayers) {
    if (CGRectContainsPoint([_tickLayers[key] frame], point)) {
      self.lastSelectedBeat = key;
      return YES;
    }
  }
  return NO;
}

- (void)setCurrentlyPlayingBeat:(NSNumber *)currentlyPlayingBeat {
  if (currentlyPlayingBeat == _currentlyPlayingBeat) {
    return;
  }
  CAShapeLayer *oldLayer = [_tickLayers objectForKey:_currentlyPlayingBeat];
  // TOOD: Constants for colours.
  oldLayer.strokeColor = [[UIColor blackColor] CGColor];
  _currentlyPlayingBeat = currentlyPlayingBeat;
  CAShapeLayer *newLayer = [_tickLayers objectForKey:_currentlyPlayingBeat];
  newLayer.strokeColor = [[UIColor lightGrayColor] CGColor];
}



@end
