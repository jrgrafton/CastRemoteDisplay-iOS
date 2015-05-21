# Google Cast Remote Display SDK EAP
_April 24 2015 release_

Sample code to demonstrate how to send UIKit, OpenGL ES or Metal content to a Google Cast receiver via Remote Display.

**THIS IS VERY EARLY SAMPLE CODE. IT MAY NOT CONTAIN UP TO DATE OR ACCURATE INFORMATION. NOTHING IS FINAL, INCLUDING APIS AND FEATURES.**

### Release notes
**April 25, 2015**
- The Remote Display SDK is now a static library. The previous method of integration no longer applies.
- Media streams are now encrypted.
- Backgrounding is supported. See GCKRemoteDisplayChannel.h.
- The core SDK no longer contains any Remote Display functionality.
- GCKRemoteDisplaySessionManager is gone. All functionality has been subsumed by GCKRemoteDisplayChannel.
- Sender apps are now responsible for launching their own Remote Display receiver app using the core SDK. The included sample code demonstrates how to do this. **For the EAP program only, use C01EB1F7. This App ID will stop working after the program concludes.**

### Installing the SDKs

-  Expand the Google Cast SDK and place the framework and asset bundle in the GoogleCastSDK folder.
-  Expand the Google Cast Remote Display SDK and place the framework in the GoogleCastRemoteDisplaySDK folder.

### Requirements

Google Cast Remote Display requires iOS 8.0 or later because it relies on hardware accelerated video and audio encoding. However, your application is not required to be restricted to iOS 8 even if it supports Remote Display.

A Remote Display receiver App ID is required. It can be shared across Android, iOS and Chrome clients if desired. The Google Cast Developer Portal will allow creating Remote Display App IDs in the future.

### Integration

You must link the Google Cast Remote Display framework SDK as well as the core Google Cast SDK in your app. Since they are both static libraries, only the required symbols and architectures will be included in the final app binary. You must also include the core SDK's asset bundle.

The app must also link required system libraries and frameworks, which include libsqlite3, AudioToolbox, CoreMedia, CoreVideo, QuartzCore and VideoToolbox. These system dependencies can be weak linked.

### Future improvements

- Provide additional APIs for audio buffer submission based on AVPCMAudioBuffer.
- Provide additional APIs to enqueue YCbCr video buffers directly.
- Improve performance of RGB to YCbCr conversion.
- Simplify the GCKRemoteDisplayConfiguration class significantly.