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

#import <GoogleCast/GoogleCast.h>
#import <GoogleCastRemoteDisplay/GoogleCastRemoteDisplay.h>

#import "ChromecastDeviceController.h"
#import "InitialViewController.h"


@interface InitialViewController () <
    ChromecastDeviceControllerDelegate,
    GCKRemoteDisplayChannelDelegate
>
/**
 *  Outlet for the Play button on the home screen.
 */
@property (weak, nonatomic) IBOutlet UIButton *playButton;

/**
 *  Outlet for the activity indicator when scanning.
 */
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;
@end

@implementation InitialViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  [ChromecastDeviceController sharedInstance].delegate = self;
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  [self updateButtonDisplay];
  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(updateButtonDisplay)
             name:@"castScanStatusUpdated"
           object:nil];
}


- (void)viewWillDisappear:(BOOL)animated {
  [super viewWillDisappear:animated];
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}


# pragma mark - UI 

- (void)updateButtonDisplay {
  if ([ChromecastDeviceController sharedInstance].deviceScanner.devices.count > 0) {
    _playButton.hidden = NO;
    [_activityIndicator stopAnimating];
  } else {
    _playButton.hidden = YES;
    [_activityIndicator startAnimating];
  }
}

- (IBAction)didTapPlay:(id)sender {
  _playButton.hidden = YES;
  [_activityIndicator startAnimating];
  [[ChromecastDeviceController sharedInstance] chooseDevice:self];
}

# pragma mark - ChromecastDeviceControllerDelegate

- (void)didConnectToDevice:(GCKDevice *)device {
  _playButton.hidden = YES;
  [_activityIndicator startAnimating];
  ChromecastDeviceController *deviceController = [ChromecastDeviceController sharedInstance];

  // Try to initialise the streaming session.
  deviceController.remoteDisplayChannel = [[GCKRemoteDisplayChannel alloc] init];
  deviceController.remoteDisplayChannel.delegate = self;
  [deviceController.deviceManager addChannel:deviceController.remoteDisplayChannel];
}

#pragma mark - GCKRemoteDisplayChannelDelegate

// TODO: check request ID on launch applicaiton, reset if so:
//if (requestID == kGCKInvalidRequestID) [self _resetCast];


- (void)remoteDisplayChannelDidConnect:(GCKRemoteDisplayChannel*)channel {
  GCKRemoteDisplayConfiguration* configuration = [GCKRemoteDisplayConfiguration new];
  configuration.videoStreamDescriptor.frameRate = GCKRemoteDisplayFrameRate60p;

  if (![channel beginSessionWithConfiguration:configuration error:NULL]) {
    [self updateButtonDisplay];
  }
}

- (void)remoteDisplayChannel:(GCKRemoteDisplayChannel*)channel
             didBeginSession:(GCKRemoteDisplaySession*)session {
  [ChromecastDeviceController sharedInstance].remoteDisplaySession = session;
  [self updateButtonDisplay];

  // Trigger the display of the second screen control.
  [self performSegueWithIdentifier:@"showCube" sender:self];
}

- (void)remoteDisplayChannel:(GCKRemoteDisplayChannel*)channel
 deviceRejectedConfiguration:(GCKRemoteDisplayConfiguration*)configuration
                       error:(NSError*)error {
  [self updateButtonDisplay];
}



@end
