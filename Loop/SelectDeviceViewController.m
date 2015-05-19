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
#import "SelectDeviceViewController.h"

#import <GoogleCast/GoogleCast.h>

static NSString * const kDeviceSelectorCell = @"castPickerCell";
static NSString * const kShowBeatsSegue = @"showBeats";

@interface SelectDeviceViewController () <
  UITableViewDelegate,
  UITableViewDataSource,
  GCKDeviceScannerListener
>
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (nonatomic) GCKDeviceScanner *scanner;
@end

@implementation SelectDeviceViewController

- (void)viewDidLoad {
  [super viewDidLoad];

  GCKFilterCriteria *filter = [GCKFilterCriteria criteriaForAvailableApplicationWithID:@"C01EB1F7"];
  self.scanner = [[GCKDeviceScanner alloc] initWithFilterCriteria:filter];
  [_scanner addListener:self];
  _tableView.hidden = YES;
}

- (void)viewWillAppear:(BOOL)animated {
  [_scanner startScan];
}

- (void)viewWillDisappear:(BOOL)animated {
  [_scanner stopScan];
}

- (IBAction)didTapPlayButton:(id)sender {
  _tableView.hidden = NO;
}

# pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  // Selected a device, pass it through to the connection logic.
  // TODO: Add it to the CastRemoteDisplayManager connection
  // TODO: Check the indexpath is still valid.
  [CastRemoteDisplayManager sharedInstance].device = _scanner.devices[indexPath.row];
  [self performSegueWithIdentifier:kShowBeatsSegue sender:self];

}

# pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView
    numberOfRowsInSection:(NSInteger)section {
  return _scanner.devices.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kDeviceSelectorCell];
  cell.textLabel.text = [_scanner.devices[indexPath.row] friendlyName];
  return cell;
}

# pragma mark - GCKDeviceScannerListener

- (void)deviceDidComeOnline:(GCKDevice *)device {
  [_tableView reloadData];
}

- (void)deviceDidGoOffline:(GCKDevice *)device {
  [_tableView reloadData];
}

@end
