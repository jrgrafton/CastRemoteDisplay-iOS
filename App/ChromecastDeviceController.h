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

@import UIKit;

#import <GoogleCast/GCKDeviceScanner.h>
#import <GoogleCast/GCKMediaStatus.h>

@class GCKDevice;
@class GCKDeviceManager;
@class GCKRemoteDisplayChannel;
@class GCKRemoteDisplaySession;

extern NSString * const kCastViewController;

@protocol ChromecastDeviceControllerDelegate <NSObject>

@optional

/**
 * Called when connection to the device was established.
 *
 * @param device The device to which the connection was established.
 */
- (void)didConnectToDevice:(GCKDevice*)device;

/**
 *  Called when the device disconnects.
 */
- (void)didDisconnect;

/**
 * Called when Cast devices are discoverd on the network.
 */
- (void)didDiscoverDeviceOnNetwork;

@end

@interface ChromecastDeviceController : NSObject <
    GCKDeviceScannerListener
>

/**
 *  The storyboard contianing the Cast component views used by the controllers in
 *  the CastComponents group.
 */
@property(nonatomic, readonly) UIStoryboard *storyboard;

/**
 *  The delegate for this object.
 */
@property(nonatomic, weak) id<ChromecastDeviceControllerDelegate> delegate;

/**
 *  The Cast application ID to launch.
 */
@property(nonatomic, copy) NSString *applicationID;

/**
 *  The device manager used to manage a connection to a Cast device.
 */
@property(nonatomic, strong) GCKDeviceManager* deviceManager;

/**
 *  The device scanner used to detect devices on the network.
 */
@property(nonatomic, strong) GCKDeviceScanner* deviceScanner;

/**
 *  The remote display channel to use.
 */
@property(nonatomic, strong) GCKRemoteDisplayChannel *remoteDisplayChannel;

/**
 *  The remote display session to send data over.
 */
@property(nonatomic, strong) GCKRemoteDisplaySession *remoteDisplaySession;

/**
 *  Main access point for the class. Use this to retrieve an object you can use.
 *
 *  @return ChromecastDeviceController
 */
+ (instancetype)sharedInstance;

/**
 *  Connect to the given Cast device.
 *
 *  @param device A GCKDevice from the deviceScanner list.
 */
- (void)connectToDevice:(GCKDevice *)device;

/**
 *  Prevent automatically reconnecting to the Cast device if we see it again.
 */
- (void)clearPreviousSession;

/**
 *  Enable basic logging of all GCKLogger messages to the console.
 */
- (void)enableLogging;

/**
 *  Display a device chooser.
 *
 *  @param sender The sending object..
 */
- (void)chooseDevice:(UIViewController *)sender;

@end
