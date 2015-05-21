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

#import "RootViewController.h"

#import <GoogleCast/GoogleCast.h>
#import <GoogleCastRemoteDisplay/GoogleCastRemoteDisplay.h>
#import <TargetConditionals.h>

#import "CastDevicesTableViewController.h"
#import "CastRemoteDisplaySupport.h"

#if TARGET_OS_EMBEDDED
#import <Metal/Metal.h>
#endif

// This the test app ID for Google Cast Remote Display.
static NSString* const kAppId = @"C01EB1F7";

@interface RootViewController () <UIPopoverPresentationControllerDelegate, GCKDeviceManagerDelegate,
                                  GCKRemoteDisplayChannelDelegate>
@end

@implementation RootViewController {
  UITapGestureRecognizer* _tapRecognizer;
  UIView* __weak _fullscreenVictimSuperview;
  BOOL _hideHud;

  GCKUICastButton* _castButton;
  GCKDeviceManager* _castDeviceManager;
  NSString* _castAppSessionID;
  GCKRemoteDisplayChannel* _castRemoteDisplayChannel;
  GCKRemoteDisplaySession* _castRemoteDisplaySession;
  BOOL _negotiatingSession;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad {
  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(_handleCastRemoteDisplayAvailableNotification:)
             name:CastRemoteDisplayAvailableNotification
           object:nil];
  _tapRecognizer =
      [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleHud:)];

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

  [super viewDidLoad];
}

- (void)viewDidLayoutSubviews {
  [super viewDidLayoutSubviews];
  if (_castButton) {
    _castButton.frame = CGRectMake(30, 45, 40, 40);
  }
}

- (void)setSelectedViewController:(UIViewController*)selectedViewController {
  UIViewController* previousVC = self.selectedViewController;
  [previousVC.view removeGestureRecognizer:_tapRecognizer];
  ((id<CastRemoteDisplayDemoController>)previousVC).castRemoteDisplaySession = nil;

  [super setSelectedViewController:selectedViewController];

  [selectedViewController.view addGestureRecognizer:_tapRecognizer];
  [self _updateSelectedCastController];
}

- (IBAction)displayCastDeviceChooser:(id)sender {
  if (_castDeviceManager) {
    [self _displayDisconnectActionSheet:sender];
  } else {
    [self _displayCastDeviceChooser:sender];
  }
}

- (void)_displayCastDeviceChooser:(id)sender {
  UIStoryboard* sb = [UIStoryboard storyboardWithName:@"CastDevices" bundle:nil];
  CastDevicesTableViewController* tvc = [sb instantiateInitialViewController];
  tvc.modalPresentationStyle = UIModalPresentationPopover;
  tvc.appID = kAppId;

  UIPopoverPresentationController* ppc = tvc.popoverPresentationController;
  if ([sender isKindOfClass:[UIView class]]) {
    UIView* sendingView = sender;
    ppc.sourceView = sendingView;
    ppc.sourceRect = sendingView.bounds;
  }
  ppc.permittedArrowDirections = UIPopoverArrowDirectionAny;
  ppc.delegate = self;

  [self presentViewController:tvc animated:YES completion:nil];
}

- (void)_displayDisconnectActionSheet:(id)sender {
  UIAlertController* alert =
      [UIAlertController alertControllerWithTitle:nil
                                          message:nil
                                   preferredStyle:UIAlertControllerStyleActionSheet];
  [alert addAction:[UIAlertAction actionWithTitle:@"Disconnect"
                                            style:UIAlertActionStyleDestructive
                                          handler:^(UIAlertAction* action) {
                                            [self _resetCast];
                                          }]];
  [alert addAction:
             [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];

  if (alert.modalPresentationStyle == UIModalPresentationPopover) {
    UIPopoverPresentationController* ppc = alert.popoverPresentationController;
    if ([sender isKindOfClass:[UIView class]]) {
      UIView* sendingView = sender;
      ppc.sourceView = sendingView;
      ppc.sourceRect = sendingView.bounds;
    }
  }

  [self presentViewController:alert animated:YES completion:nil];
}

- (IBAction)cancelCastChooser:(id)sender {
  [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)unwindFromCastDeviceChooser:(UIStoryboardSegue*)unwindSegue {
  CastDevicesTableViewController* tvc = unwindSegue.sourceViewController;
  GCKDevice* device = tvc.selectedDevice;
  if (!device) return;

  _castDeviceManager =
      [[GCKDeviceManager alloc] initWithDevice:device
                             clientPackageName:[NSBundle mainBundle].bundleIdentifier
                   ignoreAppStateNotifications:YES];
  _castDeviceManager.delegate = self;

  _negotiatingSession = YES;
  [self _updateSelectedCastController];

  [_castDeviceManager connect];
}

- (IBAction)toggleHud:(id)sender {
  _hideHud = !_hideHud;
  [self _updateSelectedCastController];
}

- (void)_resetCast {
  if (_castAppSessionID) [_castDeviceManager stopApplicationWithSessionID:_castAppSessionID];
  [_castDeviceManager disconnectWithLeave:YES];

  _castRemoteDisplaySession = nil;
  _castRemoteDisplayChannel = nil;
  _castAppSessionID = nil;
  _castDeviceManager = nil;

  _negotiatingSession = NO;
  [self _updateSelectedCastController];
}

- (void)_handleCastRemoteDisplayAvailableNotification:(NSNotification*)notification {
  _castButton = [GCKUICastButton castButtonWithTintColor:[UIColor whiteColor]
                                                  target:self
                                                selector:@selector(displayCastDeviceChooser:)];
  [self.view addSubview:_castButton];

  [self _updateSelectedCastController];
}

- (void)_updateSelectedCastController {
  UIViewController* vc = self.selectedViewController;
  id<CastRemoteDisplayDemoController> controller = (id<CastRemoteDisplayDemoController>)vc;

  if (controller.castRemoteDisplaySession != _castRemoteDisplaySession) {
    controller.castRemoteDisplaySession = _castRemoteDisplaySession;
  }

  if (_hideHud) {
    _castButton.castState = GCKUICastBarButtonItemStateUnavailable;
  } else if (_negotiatingSession) {
    _castButton.castState = GCKUICastBarButtonItemStateConnecting;
  } else if (_castRemoteDisplaySession) {
    _castButton.castState = GCKUICastBarButtonItemStateConnected;
  } else {
    _castButton.castState = GCKUICastBarButtonItemStateNotConnected;
  }

  if (_hideHud && !_fullscreenVictimSuperview) {
    _fullscreenVictimSuperview = vc.view.superview;
    [self.view.superview addSubview:vc.view];
  } else if (!_hideHud && _fullscreenVictimSuperview) {
    [_fullscreenVictimSuperview addSubview:[self.view.superview.subviews lastObject]];
    _fullscreenVictimSuperview = nil;
  }
}

#pragma mark - UIPopoverPresentationControllerDelegate

- (UIModalPresentationStyle)adaptivePresentationStyleForPresentationController:
    (UIPresentationController*)controller {
  return UIModalPresentationOverFullScreen;
}

- (UIViewController*)presentationController:(UIPresentationController*)controller
 viewControllerForAdaptivePresentationStyle:(UIModalPresentationStyle)style {
  UINavigationController* navc = [[UINavigationController alloc]
      initWithRootViewController:controller.presentedViewController];
  UIBarButtonItem* cancel_button =
      [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                    target:self
                                                    action:@selector(cancelCastChooser:)];
  controller.presentedViewController.navigationItem.rightBarButtonItem = cancel_button;
  return navc;
}

#pragma mark - GCKDeviceManagerDelegate

- (void)deviceManagerDidConnect:(GCKDeviceManager*)deviceManager {
  GCKLaunchOptions* options = [[GCKLaunchOptions alloc] initWithRelaunchIfRunning:YES];
  NSInteger requestID = [deviceManager launchApplication:@"C01EB1F7" withLaunchOptions:options];
  if (requestID == kGCKInvalidRequestID) [self _resetCast];
}

- (void)deviceManager:(GCKDeviceManager*)deviceManager didFailToConnectWithError:(NSError*)error {
  [self _resetCast];
}

- (void)deviceManager:(GCKDeviceManager*)deviceManager didDisconnectWithError:(NSError*)error {
  [self _resetCast];
}

- (void)deviceManager:(GCKDeviceManager*)deviceManager
    didConnectToCastApplication:(GCKApplicationMetadata*)applicationMetadata
                      sessionID:(NSString*)sessionID
            launchedApplication:(BOOL)launchedApplication {
  _castAppSessionID = sessionID;

  _castRemoteDisplayChannel = [[GCKRemoteDisplayChannel alloc] init];
  _castRemoteDisplayChannel.delegate = self;
  [deviceManager addChannel:_castRemoteDisplayChannel];
}

- (void)deviceManager:(GCKDeviceManager*)deviceManager
    didFailToConnectToApplicationWithError:(NSError*)error {
  [self _resetCast];
}

- (void)deviceManager:(GCKDeviceManager*)deviceManager
    didDisconnectFromApplicationWithError:(NSError*)error {
  [self _resetCast];
}

#pragma mark - GCKRemoteDisplayChannelDelegate

- (void)remoteDisplayChannelDidConnect:(GCKRemoteDisplayChannel*)channel {
  GCKRemoteDisplayConfiguration* configuration = [GCKRemoteDisplayConfiguration new];
  configuration.videoStreamDescriptor.frameRate = GCKRemoteDisplayFrameRate60p;

  if (![channel beginSessionWithConfiguration:configuration error:NULL]) [self _resetCast];
}

- (void)remoteDisplayChannel:(GCKRemoteDisplayChannel*)channel
             didBeginSession:(GCKRemoteDisplaySession*)session {
  _castRemoteDisplaySession = session;
  _negotiatingSession = NO;
  [self _updateSelectedCastController];
}

- (void)remoteDisplayChannel:(GCKRemoteDisplayChannel*)channel
 deviceRejectedConfiguration:(GCKRemoteDisplayConfiguration*)configuration
                       error:(NSError*)error {
  [self _resetCast];
}

@end
