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

#import "AppDelegate.h"
#import "ChromecastDeviceController.h"
#import "CastRemoteDisplaySupport.h"

#import <GoogleCastRemoteDisplay/GCKRemoteDisplayChannel.h>

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(UIApplication*)application {
  [[ChromecastDeviceController sharedInstance] enableLogging];
  // Set the receiver application ID to initialise scanning.
  // TODO(ianbarber): Remove before release to encourage registering own app.
  [ChromecastDeviceController sharedInstance].applicationID = @"C01EB1F7";

  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
    // Test whether we can use remote display. Because this may take some time,
    // we make the call asynchronously with the rest of the app initialization.
    BOOL remoteDisplayAvailable = [GCKRemoteDisplayChannel isRemoteDisplaySupported];
    NSLog(@"Cast Remote Display is %@", (remoteDisplayAvailable) ? @"supported" : @"not supported");

    dispatch_async(dispatch_get_main_queue(), ^{
      if (remoteDisplayAvailable) {
        [[NSNotificationCenter defaultCenter]
            postNotificationName:CastRemoteDisplayAvailableNotification
                          object:nil];
      } else {
        UIAlertView* alert =
            [[UIAlertView alloc] initWithTitle:@"Cast Remote Display is not available."
                                       message:@"iOS 8 and app support are required."
                                      delegate:nil
                             cancelButtonTitle:@"Dismiss"
                             otherButtonTitles:nil];
        [alert show];
      }
    });
  });
}

@end
