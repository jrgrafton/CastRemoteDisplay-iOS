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

#import "ChromecastDeviceController.h"
#import "DeviceTableViewController.h"

#import <GoogleCast/GoogleCast.h>

/**
 *  Constant for the storyboard ID for the device table view controller.
 */
static NSString * const kDeviceTableViewController = @"deviceTableViewController";

/**
 *  Constant for the storyboard ID for the expanded view Cast controller.
 */
NSString * const kCastViewController = @"castViewController";

@interface ChromecastDeviceController() <
    DeviceTableViewControllerDelegate,
    GCKDeviceManagerDelegate,
    GCKLoggerDelegate
>

/**
 *  The core storyboard containing the UI for the Cast components.
 */
@property(nonatomic, readwrite) UIStoryboard *storyboard;

/**
 *  Whether or not we are attempting reconnect.
 */
@property(nonatomic) BOOL isReconnecting;

@end

@implementation ChromecastDeviceController

#pragma mark - Lifecycle

+ (instancetype)sharedInstance {
  static dispatch_once_t p = 0;
  __strong static id _sharedDeviceController = nil;

  dispatch_once(&p, ^{
    _sharedDeviceController = [[self alloc] init];
  });

  return _sharedDeviceController;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    // Load the storyboard for the Cast component UI.
    self.storyboard = [UIStoryboard storyboardWithName:@"CastComponents" bundle:nil];
  }
  return self;
}

# pragma mark - Acessors

/**
 *  Set the application ID and initialise a scan.
 *
 *  @param applicationID Cast application ID
 */
- (void)setApplicationID:(NSString *)applicationID {
  _applicationID = applicationID;
  // Create filter criteria to only show devices that can run your app
  GCKFilterCriteria * filterCriteria =
      [GCKFilterCriteria criteriaForAvailableApplicationWithID:applicationID];

  // Add the criteria to the scanner to only show devices that can run your app.
  // This allows you to publish your app to the Apple App store before before publishing in Cast
  // console. Once the app is published in Cast console the cast icon will begin showing up on ios
  // devices. If an app is not published in the Cast console the cast icon will only appear for
  // whitelisted dongles
  self.deviceScanner = [[GCKDeviceScanner alloc] initWithFilterCriteria:filterCriteria];

  // Always start a scan as soon as we have an application ID.
  NSLog(@"Starting Scan");
  [self.deviceScanner addListener:self];
  [self.deviceScanner startScan];
}

# pragma mark - UI Management

- (void)chooseDevice:(UIViewController *)sender {
  UINavigationController *dtvc = (UINavigationController *)
      [_storyboard instantiateViewControllerWithIdentifier:kDeviceTableViewController];
  if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
    dtvc.modalPresentationStyle = UIModalPresentationFormSheet;
  }
  ((DeviceTableViewController *)dtvc.viewControllers[0]).delegate = self;
  ((DeviceTableViewController *)dtvc.viewControllers[0]).viewController = sender;
  [sender presentViewController:dtvc animated:YES completion:nil];
}

- (void)dismissDeviceTable:(UIViewController *)sender {
  [sender dismissViewControllerAnimated:YES completion:nil];
}

# pragma mark - GCKDeviceManagerDelegate

- (void)deviceManagerDidConnect:(GCKDeviceManager *)deviceManager {
  if (!self.isReconnecting
      || ![deviceManager.applicationMetadata.applicationID isEqualToString:_applicationID]) {
    [self.deviceManager launchApplication:_applicationID];
  } else {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString* lastSessionID = [defaults valueForKey:@"lastSessionID"];
    [self.deviceManager joinApplication:_applicationID sessionID:lastSessionID];
  }
}

- (void)deviceManager:(GCKDeviceManager *)deviceManager
didConnectToCastApplication:(GCKApplicationMetadata *)applicationMetadata
            sessionID:(NSString *)sessionID
  launchedApplication:(BOOL)launchedApplication {
  [[NSNotificationCenter defaultCenter] postNotificationName:@"castApplicationConnected"
                                                      object:self];

  if ([self.delegate respondsToSelector:@selector(didConnectToDevice:)]) {
    [self.delegate didConnectToDevice:deviceManager.device];
  }

  self.isReconnecting = NO;
  // Store sessionID in case of restart
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject:sessionID forKey:@"lastSessionID"];
  [defaults setObject:deviceManager.device.deviceID forKey:@"lastDeviceID"];
  [defaults synchronize];
}

- (void)deviceManager:(GCKDeviceManager *)deviceManager
    volumeDidChangeToLevel:(float)volumeLevel
                   isMuted:(BOOL)isMuted {
  [[NSNotificationCenter defaultCenter] postNotificationName:@"castVolumeChanged" object:self];
}

- (void)deviceManager:(GCKDeviceManager *)deviceManager
    didFailToConnectWithError:(GCKError *)error {
  [self clearPreviousSession];
}

- (void)deviceManager:(GCKDeviceManager *)deviceManager didDisconnectWithError:(GCKError *)error {
  NSLog(@"Received notification that device disconnected");

  if (!error || (
      error.code == GCKErrorCodeDeviceAuthenticationFailure ||
      error.code == GCKErrorCodeDisconnected ||
      error.code == GCKErrorCodeApplicationNotFound)) {
    [self clearPreviousSession];
  }
}

- (void)deviceManager:(GCKDeviceManager *)deviceManager
    didDisconnectFromApplicationWithError:(NSError *)error {
  NSLog(@"Received notification that app disconnected");

  if (error) {
    NSLog(@"Application disconnected with error: %@", error);
  }

  if (_delegate && [_delegate respondsToSelector:@selector(didDisconnect)]) {
    [_delegate didDisconnect];
  }
}

# pragma mark - Reconnection

- (void)clearPreviousSession {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults removeObjectForKey:@"lastDeviceID"];
  [defaults synchronize];
}

# pragma mark - GCKDeviceScannerListener

- (void)deviceDidComeOnline:(GCKDevice *)device {
  NSLog(@"device found - %@", device.friendlyName);

  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString* lastDeviceID = [defaults objectForKey:@"lastDeviceID"];
  if (lastDeviceID != nil && [[device deviceID] isEqualToString:lastDeviceID]){
    self.isReconnecting = YES;
    [self connectToDevice:device];
  }

  if ([self.delegate respondsToSelector:@selector(didDiscoverDeviceOnNetwork)]) {
    [self.delegate didDiscoverDeviceOnNetwork];
  }

  [[NSNotificationCenter defaultCenter] postNotificationName:@"castScanStatusUpdated" object:self];
}

- (void)deviceDidGoOffline:(GCKDevice *)device {
  NSLog(@"device went offline - %@", device.friendlyName);
  [[NSNotificationCenter defaultCenter] postNotificationName:@"castScanStatusUpdated" object:self];
}

- (void)deviceDidChange:(GCKDevice *)device {
  [[NSNotificationCenter defaultCenter] postNotificationName:@"castScanStatusUpdated" object:self];
}

# pragma mark - Device & Media Management

- (void)connectToDevice:(GCKDevice *)device {
  NSLog(@"Connecting to device address: %@:%d", device.ipAddress, (unsigned int)device.servicePort);

  NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
  NSString *appIdentifier = [info objectForKey:@"CFBundleIdentifier"];
  self.deviceManager =
      [[GCKDeviceManager alloc] initWithDevice:device clientPackageName:appIdentifier];
  self.deviceManager.delegate = self;
  [self.deviceManager connect];
}

#pragma mark - GCKLoggerDelegate implementation

- (void)enableLogging {
  [[GCKLogger sharedInstance] setDelegate:self];
}

- (void)logFromFunction:(const char *)function message:(NSString *)message {
  // Send SDK’s log messages directly to the console, as an example.
  NSLog(@"%s  %@", function, message);
}

@end
