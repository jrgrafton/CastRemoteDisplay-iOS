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

#import <Foundation/Foundation.h>

@class GCKDevice;
@class GCKRemoteDisplaySession;

/**
 *  Subscribe to NSNotificationCenter notifications with this name in order to be updated when
 *  when the remote display session is initiated.
 */
extern NSString * const kLOOPRemoteDisplayDidConnectNotification;

@interface CastRemoteDisplayManager : NSObject

/**
 *  Accessor for the singleton.
 *
 *  @return CastRemoteDisplayManager
 */
+ (instancetype)sharedInstance;

/**
 *  Do not init this object directly - use the sharedInstance singleton above.
 */
- (instancetype)init __attribute__((unavailable("Please use +sharedInstance: instead.")));

/**
 *  The GCKDevice to connect to. Will automatically attempt to connect and establish a remote
 *  display session once this property is set.
 */
@property(nonatomic, strong) GCKDevice* device;

/**
 *  The remote display session, if available. If consuming this session, the code should subscribe
 *  for notifications and then check the status of this session object - proceeding if it is not
 *  null as if the notification had been fired.
 */
@property (nonatomic, readonly) GCKRemoteDisplaySession *session;
@end
