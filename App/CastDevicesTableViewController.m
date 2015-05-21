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

#import "CastDevicesTableViewController.h"

#import <GoogleCast/GoogleCast.h>

@interface CastDevicesTableViewController () <GCKDeviceScannerListener>
@end

@implementation CastDevicesTableViewController {
  GCKDeviceScanner* _castScanner;
  NSMutableArray* _devices;
}

@dynamic selectedDevice;

- (void)viewDidLoad {
  [super viewDidLoad];

  _devices = [NSMutableArray new];
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];

  [self maybeStartScanner];
}

- (void)viewDidDisappear:(BOOL)animated {
  [super viewDidDisappear:animated];

  [self resetScanner];
}

- (void)setAppID:(NSString *)appID {
  if (appID && [_appID isEqualToString:appID]) return;
  _appID = [appID copy];
  [self resetScanner];
  [self maybeStartScanner];
}

- (void)maybeStartScanner {
  if (_castScanner) return;
  if (_appID.length == 0) return;

  _castScanner = [[GCKDeviceScanner alloc]
      initWithFilterCriteria:[GCKFilterCriteria criteriaForAvailableApplicationWithID:_appID]];
  [_castScanner addListener:self];
  [_castScanner startScan];
}

- (void)resetScanner {
  [_castScanner stopScan];
  _castScanner = nil;
}

- (GCKDevice*)selectedDevice {
  NSIndexPath* selection = self.tableView.indexPathForSelectedRow;
  return (selection) ? _devices[selection.row] : nil;
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView*)tableView {
  return 1;
}

- (NSInteger)tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section {
  return _devices.count;
}

- (UITableViewCell*)tableView:(UITableView*)tableView
        cellForRowAtIndexPath:(NSIndexPath*)indexPath {
  UITableViewCell* cell =
      [tableView dequeueReusableCellWithIdentifier:@"com.google.cast-device-cell"
                                      forIndexPath:indexPath];
  cell.textLabel.text = [_devices[indexPath.row] friendlyName];
  return cell;
}

#pragma mark - GCKDeviceScannerListener

- (void)deviceDidComeOnline:(GCKDevice*)device {
  NSInteger index =
      [_devices indexOfObject:device
                inSortedRange:NSMakeRange(0, _devices.count)
                      options:NSBinarySearchingInsertionIndex
              usingComparator:^NSComparisonResult(id lhs, id rhs) {
                GCKDevice* lhs_device = lhs;
                GCKDevice* rhs_device = rhs;
                return [lhs_device.friendlyName localizedCompare:rhs_device.friendlyName];
              }];
  [_devices insertObject:device atIndex:index];
  [self.tableView insertRowsAtIndexPaths:@[ [NSIndexPath indexPathForRow:index inSection:0] ]
                        withRowAnimation:UITableViewRowAnimationAutomatic];
}

- (void)deviceDidGoOffline:(GCKDevice*)device {
  NSUInteger index = [_devices indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL* stop) {
    GCKDevice* otherDevice = obj;
    return [device isSameDeviceAs:otherDevice];
  }];
  if (index != NSNotFound) {
    [_devices removeObjectAtIndex:index];
    [self.tableView deleteRowsAtIndexPaths:@[ [NSIndexPath indexPathForRow:index inSection:0] ]
                          withRowAnimation:UITableViewRowAnimationAutomatic];
  }
}

@end
