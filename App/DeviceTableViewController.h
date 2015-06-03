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

#import <UIKit/UIKit.h>

@class GCKDevice;
@class GCKDeviceManager;
@class GCKDeviceScanner;
@class GCKMediaControlChannel;
@class GCKMediaInformation;

@protocol DeviceTableViewControllerDelegate <NSObject>

/**
 *  Return a GCKDeviceScanner to use for the displayed devices.
 *
 *  @return an initialised device scanner
 */
- (GCKDeviceScanner *)deviceScanner;

/**
 *  Return a  GCKDeviceManager so the picker can display the currently playing media
 *  in case it is connected.
 *
 *  @return a manager, or nil
 */
- (GCKDeviceManager *)deviceManager;

/**
 *  Connect to the given Cast device.
 *
 *  @param device A GCKDevice from the deviceScanner list.
 */
- (void)connectToDevice:(GCKDevice *)device;

@optional

/**
 * Disconnect and stop the application.
 */
- (void)disconnect;

@end

/**
 * A popup view to display list of chromecast devices to connect. When connected,
 * offers button to disconnect. When playing media, displays a mini playback
 * controller.
 */
@interface DeviceTableViewController : UITableViewController

/**
 *  The delegate for the device picker.
 */
@property(nonatomic, weak) id<DeviceTableViewControllerDelegate> delegate;

/**
 *  The view controller the device picker was presented from.
 */
@property(nonatomic, weak) UIViewController *viewController;

@end