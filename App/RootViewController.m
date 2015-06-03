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

#import "CastRemoteDisplaySupport.h"
#import "ChromecastDeviceController.h"
#import "RootViewController.h"

#import <GoogleCast/GoogleCast.h>
#import <GoogleCastRemoteDisplay/GoogleCastRemoteDisplay.h>
#import <Metal/Metal.h>
#import <TheAmazingAudioEngine/TheAmazingAudioEngine.h>


@interface RootViewController () <ChromecastDeviceControllerDelegate>
@property(nonatomic) AEAudioFilePlayer *loop;
@property(nonatomic) AEAudioController *audioController;
@end

@implementation RootViewController

- (void)viewDidLoad {
  [super viewDidLoad];

  [ChromecastDeviceController sharedInstance].delegate = self;

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

  self.audioController =
      [[AEAudioController alloc]
          initWithAudioDescription:[AEAudioController nonInterleavedFloatStereoAudioDescription]
                      inputEnabled:NO];
  NSURL *file = [[NSBundle mainBundle] URLForResource:@"sound_new" withExtension:@"mp3"];
  self.loop = [AEAudioFilePlayer audioFilePlayerWithURL:file
                                        audioController:_audioController
                                                  error:NULL];
  _loop.loop = YES;
  [_audioController addChannels:@[_loop]];

  // Block the main output. Our receiver above will still receive the channel sound.
  _audioController.muteOutput = YES;

  NSError *error = NULL;
  BOOL result = [_audioController start:&error];
  if (!result) {
    NSLog(@"Error starting TAEE Audio Controller: %@", error);
  }

  // Add a new output receiver pushing to the remote display. TAEE defaults to 1024 buffers, which
  // should work for us!
  id<AEAudioReceiver> receiver = [AEBlockAudioReceiver audioReceiverWithBlock:
                                  ^(void                     *source,
                                    const AudioTimeStamp     *time,
                                    UInt32                    frames,
                                    AudioBufferList          *audio) {
                                    ChromecastDeviceController *ccdc =
                                        [ChromecastDeviceController sharedInstance];
                                    GCKRemoteDisplaySession *session = ccdc.remoteDisplaySession;
                                    if (audio && session) {
                                      [session enqueueAudioBuffer:audio
                                                           frames:frames
                                                              pts:time];
                                    }
                                  }];
  [self.audioController addOutputReceiver:receiver forChannel:_loop];
  _loop.channelIsPlaying = YES;
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  [self updateSelectedCastController];
  [ChromecastDeviceController sharedInstance].delegate = self;
}

- (void)viewWillDisappear:(BOOL)animated {
  [super viewWillDisappear:animated];
}

- (void)setSelectedViewController:(UIViewController*)selectedViewController {
  UIViewController* previousVC = self.selectedViewController;
  ((id<CastRemoteDisplayDemoController>)previousVC).castRemoteDisplaySession = nil;

  [super setSelectedViewController:selectedViewController];

  [self updateSelectedCastController];
}

- (IBAction)didTapCastIcon:(id)sender {
  // Trigger the device chooser to allow disconnect.
  [[ChromecastDeviceController sharedInstance] chooseDevice:self];
}

- (void)updateSelectedCastController {
  UIViewController* vc = self.selectedViewController;
  id<CastRemoteDisplayDemoController> controller = (id<CastRemoteDisplayDemoController>)vc;
  GCKRemoteDisplaySession *remoteDisplaySession =
      [ChromecastDeviceController sharedInstance].remoteDisplaySession;

  if (controller.castRemoteDisplaySession != remoteDisplaySession) {
    controller.castRemoteDisplaySession = remoteDisplaySession;
  }
}

#pragma mark - ChromecastDeviceController

- (void)didDisconnect {
  [ChromecastDeviceController sharedInstance].remoteDisplaySession = nil;
  // Bounce back to the main view.
  [self performSegueWithIdentifier:@"unwindSegue" sender:self];
}

@end
