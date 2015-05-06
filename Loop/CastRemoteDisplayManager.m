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

#import "CastRemoteDisplayManager.h"

#import <GoogleCast/GoogleCast.h>
#import <GoogleCastRemoteDisplay/GoogleCastRemoteDisplay.h>

NSString * const kLOOPRemoteDisplayDidConnectNotification =
    @"LOOPRemoteDisplayDidConnectNotification";

@interface CastRemoteDisplayManager () <GCKDeviceManagerDelegate, GCKRemoteDisplayChannelDelegate>

// TODO(ianbarber): Comment all this business.
@property (nonatomic) GCKDeviceManager *deviceManager;
@property (nonatomic, readwrite) GCKRemoteDisplaySession *session;
@property (nonatomic) GCKRemoteDisplayChannel *channel;

@end

@implementation CastRemoteDisplayManager

+ (instancetype)sharedInstance {
  static dispatch_once_t p = 0;
  __strong static id _sharedObject = nil;
  dispatch_once(&p, ^{
    _sharedObject = [[self alloc] init];
  });
  return _sharedObject;
}

- (void)setDevice:(GCKDevice *)device {
  _device = device;
  self.deviceManager =
      [[GCKDeviceManager alloc] initWithDevice:device
                             clientPackageName:[NSBundle mainBundle].bundleIdentifier
                   ignoreAppStateNotifications:YES];
  _deviceManager.delegate = self;
  [_deviceManager connect];
}

# pragma mark - GCKDeviceManagerDelegate

- (void)deviceManagerDidConnect:(GCKDeviceManager *)deviceManager {
  // TODO(ianbarber): Should we be relaunching?
  GCKLaunchOptions* options = [[GCKLaunchOptions alloc] initWithRelaunchIfRunning:YES];
  NSInteger requestID = [deviceManager launchApplication:@"C01EB1F7" withLaunchOptions:options];
  if (requestID == kGCKInvalidRequestID) {
    // TODO(ianbarber): We need to handle failure cases, including the didDisconnect type errors.
  }
}

- (void)deviceManager:(GCKDeviceManager *)deviceManager
    didFailToConnectWithError:(NSError *)error {
  NSLog(@"Failed to connect to device: %@", error.localizedDescription);
}

- (void)deviceManager:(GCKDeviceManager *)deviceManager
  didFailToConnectToApplicationWithError:(NSError *)error {
  NSLog(@"Failed to connect to app: %@", error.localizedDescription);
}

- (void)deviceManager:(GCKDeviceManager *)deviceManager
    didConnectToCastApplication:(GCKApplicationMetadata *)applicationMetadata
            sessionID:(NSString *)sessionID
  launchedApplication:(BOOL)launchedApplication {
  self.channel = [[GCKRemoteDisplayChannel alloc] init];
  _channel.delegate = self;
  [_deviceManager addChannel:_channel];
}

# pragma mark - GCKRemoteDisplayChannelDelegate

- (void)remoteDisplayChannelDidConnect:(GCKRemoteDisplayChannel *)channel {
  GCKRemoteDisplayConfiguration* configuration = [[GCKRemoteDisplayConfiguration alloc] init];
  // TODO(ianbarber): This should be fine, but it would be good to find out what sort of
  // FPS we are actually getting, and maybe target 30.
  configuration.videoStreamDescriptor.frameRate = GCKVideoFrameRate_60;
  // TODO(ianbarber): This number feels magic, how should a developer work this out?
  configuration.minExpectedDelay = 200;
  NSError *error;
  if (![_channel beginSessionWithConfiguration:configuration error:&error]) {
    // TODO(ianbarber): Handle error.
  }
}

- (void)remoteDisplayChannel:(GCKRemoteDisplayChannel *)channel
             didBeginSession:(GCKRemoteDisplaySession *)session {
  self.session = session;
  [[NSNotificationCenter defaultCenter]
      postNotificationName:kLOOPRemoteDisplayDidConnectNotification
                    object:self];
}

- (void)remoteDisplayChannel:(GCKRemoteDisplayChannel *)channel
 deviceRejectedConfiguration:(GCKRemoteDisplayConfiguration *)configuration
                       error:(NSError *)error {
  // TODO(Ianbarber): Handle error.
}

@end
