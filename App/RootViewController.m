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

#import "CastRemoteDisplaySupport.h"
#import "ChromecastDeviceController.h"
#import "RootViewController.h"

#import <GoogleCast/GoogleCast.h>
#import <GoogleCastRemoteDisplay/GoogleCastRemoteDisplay.h>
#import <TargetConditionals.h>

#if TARGET_OS_EMBEDDED
#import <Metal/Metal.h>
#endif

@interface RootViewController () <ChromecastDeviceControllerDelegate>
@property (nonatomic) UITapGestureRecognizer *tapRecognizer;
@end

@implementation RootViewController {
  UIView* __weak _fullscreenVictimSuperview;
  BOOL _hideHud;
}

- (void)viewDidLoad {
  [super viewDidLoad];

  [ChromecastDeviceController sharedInstance].delegate = self;

  // TODO(ianbarber): Reimplement tag gesture for color changing.
//  self.tapRecognizer =
//      [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleHud:)];

  BOOL hasMetal = NO;
#if TARGET_OS_EMBEDDED
  hasMetal = MTLCreateSystemDefaultDevice() != nil;
#endif

  if (!hasMetal) {
    // The last tab item is Metal. Just remove it.
    NSMutableArray* viewControllers = [self.viewControllers mutableCopy];
    [viewControllers removeLastObject];
    self.viewControllers = viewControllers;
  }
}

- (void)viewWillAppear:(BOOL)animated {
  [self updateSelectedCastController];
}

- (void)setSelectedViewController:(UIViewController*)selectedViewController {
  UIViewController* previousVC = self.selectedViewController;
  //[previousVC.view removeGestureRecognizer:_tapRecognizer];
  ((id<CastRemoteDisplayDemoController>)previousVC).castRemoteDisplaySession = nil;

  [super setSelectedViewController:selectedViewController];

  //[selectedViewController.view addGestureRecognizer:_tapRecognizer];
  [self updateSelectedCastController];
}

//- (IBAction)toggleHud:(id)sender {
//  _hideHud = !_hideHud;
//  [self _updateSelectedCastController];
//}
//
- (void)updateSelectedCastController {
  UIViewController* vc = self.selectedViewController;
  id<CastRemoteDisplayDemoController> controller = (id<CastRemoteDisplayDemoController>)vc;
  GCKRemoteDisplaySession *remoteDisplaySession =
      [ChromecastDeviceController sharedInstance].remoteDisplaySession;

  if (controller.castRemoteDisplaySession != remoteDisplaySession) {
    controller.castRemoteDisplaySession = remoteDisplaySession;
  }
//  if (_hideHud && !_fullscreenVictimSuperview) {
//    _fullscreenVictimSuperview = vc.view.superview;
//    [self.view.superview addSubview:vc.view];
//  } else if (!_hideHud && _fullscreenVictimSuperview) {
//    [_fullscreenVictimSuperview addSubview:[self.view.superview.subviews lastObject]];
//    _fullscreenVictimSuperview = nil;
//  }
}

#pragma mark - ChromecastDeviceController

// TODO: Add chromecast device controller for disconect callback, bounce back to home
// TODO: ADd button to navigation bar
// TODO: Implement button pointing to cast device chooser
// TODO: Disconnect bounce back to home screen
// TODO: Add TAEE
// TODO: Music loop
// TODO: Clean up on cube redering stuff.
// TODO: Make cast icon white, not connected icon.

@end
