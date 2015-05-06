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
@import GLKit;

#import "BeatControl.h"
#import "BeatViewController.h"
#import "CastRemoteDisplayManager.h"

#import <GoogleCastRemoteDisplay/GoogleCastRemoteDisplay.h>
#import <MHRotaryKnob/MHRotaryKnob.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import <TheAmazingAudioEngine/TheAmazingAudioEngine.h>
#import <TheAmazingAudioEngine/AESequencerChannel.h>

static const float kBeatSixteenth = 0.0625;
static const NSInteger kTimeSignature = 4;

@interface BeatViewController ()

@property (weak, nonatomic) IBOutlet UIView *drumPadView;
@property (weak, nonatomic) IBOutlet BeatControl *beatSequenceControl;
@property (weak, nonatomic) IBOutlet MHRotaryKnob *bpmRotary;

@property (nonatomic) EAGLContext *context;
@property (nonatomic) GCKOpenGLESVideoFrameInput *castInput;
@property (nonatomic) BOOL hasSetupAudioVisual;
@property (nonatomic) GLuint castFramebuffer;
@property (nonatomic) GLuint castRenderbuffer;
@property (nonatomic) BOOL running;

@property (nonatomic) AEAudioController *audioController;
@property (nonatomic) NSInteger bpm;

@property (nonatomic) AESequencerChannelSequence *metronomeSeq;
@property (nonatomic) AESequencerChannelSequence *crashSeq;
@property (nonatomic) AESequencerChannelSequence *kickSeq;
@property (nonatomic) AESequencerChannelSequence *snareSeq;
@property (nonatomic) AESequencerChannelSequence *rimshotSeq;
@property (nonatomic) AESequencerChannelSequence *cymbalSeq;
@property (nonatomic) AESequencerChannelSequence *tomSeq;
@property (nonatomic) AEChannelGroupRef mainChannelGroup;

@property (nonatomic) AESequencerChannel *metronomeChannel;
@property (nonatomic) AESequencerChannel *crashChannel;
@property (nonatomic) AESequencerChannel *kickChannel;
@property (nonatomic) AESequencerChannel *snareChannel;
@property (nonatomic) AESequencerChannel *rimshotChannel;
@property (nonatomic) AESequencerChannel *cymbalChannel;
@property (nonatomic) AESequencerChannel *tomChannel;

@property (nonatomic) NSURL *hat;
@property (nonatomic) NSURL *crash;
@property (nonatomic) NSURL *kick;
@property (nonatomic) NSURL *snare;
@property (nonatomic) NSURL *rimshot;
@property (nonatomic) NSURL *cymbal;
@property (nonatomic) NSURL *tom;
@end

@implementation BeatViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  self.hasSetupAudioVisual = NO;
  __weak __typeof__(self) weakself = self;
  [[NSNotificationCenter defaultCenter] addObserverForName:kLOOPRemoteDisplayDidConnectNotification
                                                    object:nil
                                                     queue:nil
                                                usingBlock:^(NSNotification *note) {
                                                  if (weakself.hasSetupAudioVisual) {
                                                    return;
                                                  }
                                                  [weakself setupGLES];
                                                  [weakself setupAudio];
                                                  weakself.hasSetupAudioVisual = YES;
                                                }];

  self.audioController =
  [[AEAudioController alloc]
   initWithAudioDescription:[AEAudioController nonInterleavedFloatStereoAudioDescription]];

  self.bpm = 120;
  _bpmRotary.interactionStyle = MHRotaryKnobInteractionStyleRotating;
  _bpmRotary.scalingFactor = 1.5;
  _bpmRotary.maximumValue = 180;
  _bpmRotary.minimumValue = 80;
  _bpmRotary.defaultValue = self.bpm;
  _bpmRotary.resetsToDefault = YES;
  _bpmRotary.backgroundColor = [UIColor clearColor];
  _bpmRotary.backgroundImage = [UIImage imageNamed:@"icon_bpm_enabled"];
  // TODO(ianbarber): Proper image which is offset correctly.
  [_bpmRotary setKnobImage:[UIImage imageNamed:@"icon_bpm_select_circle"]
                  forState:UIControlStateNormal];
  [_bpmRotary addTarget:self
                 action:@selector(didFinishBpm) forControlEvents:UIControlEventTouchUpInside];
  [_bpmRotary addTarget:self
                 action:@selector(didFinishBpm) forControlEvents:UIControlEventTouchUpOutside];
  // self.rotaryKnob.knobImageCenter = CGPointMake(80.0, 76.0);
  [_bpmRotary addTarget:self
                 action:@selector(didChangeBpm)
       forControlEvents:UIControlEventValueChanged];

  self.mainChannelGroup = [_audioController createChannelGroup];
  self.metronomeSeq = [[AESequencerChannelSequence alloc] init];
  self.crashSeq = [[AESequencerChannelSequence alloc] init];
  self.kickSeq = [[AESequencerChannelSequence alloc] init];
  self.cymbalSeq = [[AESequencerChannelSequence alloc] init];
  self.crashSeq = [[AESequencerChannelSequence alloc] init];
  self.tomSeq = [[AESequencerChannelSequence alloc] init];
  self.rimshotSeq = [[AESequencerChannelSequence alloc] init];
  self.snareSeq = [[AESequencerChannelSequence alloc] init];

  self.hat = [[NSBundle mainBundle] URLForResource:@"hihat-short" withExtension:@"wav"];
  // TODO: real sound
  self.crash = [[NSBundle mainBundle] URLForResource:@"tom3" withExtension:@"wav"];
  self.kick = [[NSBundle mainBundle] URLForResource:@"kick" withExtension:@"wav"];
  // TODO: real sound.
  self.cymbal = [[NSBundle mainBundle] URLForResource:@"hihat" withExtension:@"wav"];
  // TODO: real sound.
  self.rimshot = [[NSBundle mainBundle] URLForResource:@"tom2" withExtension:@"wav"];
  self.tom = [[NSBundle mainBundle] URLForResource:@"tom1" withExtension:@"wav"];
  self.snare = [[NSBundle mainBundle] URLForResource:@"snare" withExtension:@"wav"];


  _drumPadView.hidden = YES;
  [_beatSequenceControl addTarget:self
                           action:@selector(didTouchBeatControl)
                 forControlEvents:UIControlEventTouchUpInside];

  // TODO(ianbarber): Not sure if I need to check _hasSetup as I don't think the block above
  // could have executed yet.
  if ([CastRemoteDisplayManager sharedInstance].session && !_hasSetupAudioVisual) {
    [self setupGLES];
    [self setupAudio];
    self.hasSetupAudioVisual = YES;
  }
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
    // TODO(ianbarber): Remove
  [self setupAudio];

  self.running = YES;
  // TODO(ianbarber): Could/should we replace with NSTimer?
  // [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(updateProgressView) userInfo:nil repeats:YES];
  [self renderLoop];
}

- (void)viewWillDisappear:(BOOL)animated {
  [super viewWillDisappear:animated];
  self.running = NO;
  [_audioController stop];
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
  if (_hasSetupAudioVisual) {
    glDeleteFramebuffers(1, &_castFramebuffer);
  }
}

#pragma mark - Audio

- (void)setupAudio {
  NSLog(@"Seting up audio playback for second screen output");
  NSError *audioControllerStartError = nil;
  [_audioController start:&audioControllerStartError];
  if (audioControllerStartError) {
    NSLog(@"Audio controller start error: %@", audioControllerStartError.localizedDescription);
  }

  id<AEAudioReceiver> receiver = [AEBlockAudioReceiver audioReceiverWithBlock:
                                  ^(void                     *source,
                                    const AudioTimeStamp     *time,
                                    UInt32                    frames,
                                    AudioBufferList          *audio) {
                                    // Do something with 'audio'
//                                    GCKRemoteDisplaySession *session =
//                                        [CastRemoteDisplayManager sharedInstance].session;
//                                    if (audio && session) {
//                                      [session enqueueAudioBuffer:audio
//                                                           frames:frames
//                                                              pts:time];
//                                    }
                                  }];
  [self.audioController addOutputReceiver:receiver];

  // Setup the metronome playback.
  self.metronomeSeq = [[AESequencerChannelSequence alloc] init];
  [_metronomeSeq addBeat:[AESequencerBeat beatWithOnset:kBeatSixteenth * 0]];
  [_metronomeSeq addBeat:[AESequencerBeat beatWithOnset:kBeatSixteenth * 4]];
  [_metronomeSeq addBeat:[AESequencerBeat beatWithOnset:kBeatSixteenth * 8]];
  [_metronomeSeq addBeat:[AESequencerBeat beatWithOnset:kBeatSixteenth * 12]];

  // Setup the channels to hold the playback of each instrument channel.

  self.metronomeChannel = [AESequencerChannel sequencerChannelWithAudioFileAt:_hat
                                                              audioController:_audioController
                                                                 withSequence:_metronomeSeq
                                                  numberOfFullBeatsPerMeasure:kTimeSignature
                                                                        atBPM:_bpm];
  self.metronomeChannel.volume = 0.8;

  self.snareChannel = [AESequencerChannel sequencerChannelWithAudioFileAt:_snare
                                                              audioController:_audioController
                                                                 withSequence:_snareSeq
                                                  numberOfFullBeatsPerMeasure:kTimeSignature
                                                                        atBPM:_bpm];

  self.cymbalChannel = [AESequencerChannel sequencerChannelWithAudioFileAt:_cymbal
                                                          audioController:_audioController
                                                             withSequence:_cymbalSeq
                                              numberOfFullBeatsPerMeasure:kTimeSignature
                                                                    atBPM:_bpm];

  self.tomChannel = [AESequencerChannel sequencerChannelWithAudioFileAt:_tom
                                                          audioController:_audioController
                                                             withSequence:_kickSeq
                                              numberOfFullBeatsPerMeasure:kTimeSignature
                                                                    atBPM:_bpm];

  self.rimshotChannel = [AESequencerChannel sequencerChannelWithAudioFileAt:_rimshot
                                                          audioController:_audioController
                                                             withSequence:_rimshotSeq
                                              numberOfFullBeatsPerMeasure:kTimeSignature
                                                                    atBPM:_bpm];

  self.kickChannel = [AESequencerChannel sequencerChannelWithAudioFileAt:_kick
                                                          audioController:_audioController
                                                             withSequence:_kickSeq
                                              numberOfFullBeatsPerMeasure:kTimeSignature
                                                                    atBPM:_bpm];

  self.crashChannel = [AESequencerChannel sequencerChannelWithAudioFileAt:_crash
                                                          audioController:_audioController
                                                             withSequence:_crashSeq
                                              numberOfFullBeatsPerMeasure:kTimeSignature
                                                                    atBPM:_bpm];

  // Add channels to the audio controller
  [_audioController addChannels:@[_metronomeChannel, _crashChannel, _snareChannel,
                                  _tomChannel, _cymbalChannel, _rimshotChannel, _kickChannel]
                 toChannelGroup:_mainChannelGroup];


  [self startChannels];
}

#pragma mark - OpenGL

- (void)setupGLES {
  NSLog(@"Setting up OpenGL rendering for second screen output.");
  GCKRemoteDisplaySession *session = [CastRemoteDisplayManager sharedInstance].session;

  // Configure our draw context.
  self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
  [EAGLContext setCurrentContext:_context];

  // Configure the cast input from the OpenGL ES frame buffer.
  self.castInput = [[GCKOpenGLESVideoFrameInput alloc] initWithSession:session];
  _castInput.context = _context;
  _castInput.pixelFormat = GCKPixelFormatBGRA8Unorm;

  // Generate a frame buffer name.
  glGenFramebuffers(1, &_castFramebuffer);
  glGenRenderbuffers(1, &_castRenderbuffer);
  self.running = YES;
  [self render];
}

- (void)render {
  GCKOpenGLESDrawable *drawable = [_castInput nextDrawable];
  GCKVideoStreamDescriptor *descriptor = _castInput.session.configuration.videoStreamDescriptor;
  glBindRenderbuffer(GL_RENDERBUFFER, _castRenderbuffer);
  glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24_OES, descriptor.width,
                        descriptor.height);
  glBindFramebuffer(GL_DRAW_FRAMEBUFFER_APPLE, _castFramebuffer);
  glFramebufferTexture2D(GL_DRAW_FRAMEBUFFER_APPLE, GL_COLOR_ATTACHMENT0,
                         CVOpenGLESTextureGetTarget(drawable.texture),
                         CVOpenGLESTextureGetName(drawable.texture), 0);
  glViewport(0, 0, descriptor.width, descriptor.height);
  glClearColor(1.0, 0.0, 0.0, 1.0);
  glDepthMask(GL_FALSE);
  glDisable(GL_DEPTH_TEST);
  glClear(GL_COLOR_BUFFER_BIT);
  glFinish();
  [drawable present];
}

- (void)renderLoop {
  //[self render];
  NSNumber *beat = @((int)round(16 * _metronomeChannel.playheadPosition));
  self.beatSequenceControl.currentlyPlayingBeat = beat;
  if (_running) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 16 * NSEC_PER_MSEC),
                   dispatch_get_main_queue(),
                   ^{
                     [self renderLoop];
                   });
  }
}

#pragma mark - Audio Settings

- (void)updateBpm {
  self.bpm = _bpmRotary.value;
  _metronomeChannel.bpm = self.bpm;
  _kickChannel.bpm = self.bpm;
  _crashChannel.bpm = self.bpm;
  _cymbalChannel.bpm = self.bpm;
  _tomChannel.bpm = self.bpm;
  _rimshotChannel.bpm = self.bpm;
  _snareChannel.bpm = self.bpm;
}

- (void)startChannels {
  // Start all channels playing
  _metronomeChannel.sequenceIsPlaying = YES;
  _crashChannel.sequenceIsPlaying = YES;
  _snareChannel.sequenceIsPlaying = YES;
  _tomChannel.sequenceIsPlaying = YES;
  _cymbalChannel.sequenceIsPlaying = YES;
  _rimshotChannel.sequenceIsPlaying = YES;
  _kickChannel.sequenceIsPlaying = YES;
}

- (void)stopChannels {
  // Start all channels playing
  _metronomeChannel.sequenceIsPlaying = NO;
  _crashChannel.sequenceIsPlaying = NO;
  _snareChannel.sequenceIsPlaying = NO;
  _tomChannel.sequenceIsPlaying = NO;
  _cymbalChannel.sequenceIsPlaying = NO;
  _rimshotChannel.sequenceIsPlaying = NO;
  _kickChannel.sequenceIsPlaying = NO;
}

#pragma mark - Buttons

- (void)didTouchBeatControl {
  // TODO: Shrink beat display, ignore clicks until beat chooser is done.
  _drumPadView.hidden = NO;
}

- (void)didChangeBpm {
  [self updateBpm];
}

- (void)didFinishBpm {
  self.bpmRotary.hidden = YES;
}

- (IBAction)didTapLoopButton:(id)sender {
  if (_metronomeChannel.sequenceIsPlaying) {
    [self stopChannels];
  } else {
    [self startChannels];
  }
}

- (IBAction)didTapBPMButton:(id)sender {
  self.bpmRotary.hidden = NO;
}

- (IBAction)didTapResetButton:(id)sender {
    // Sequence reset.
  self.kickSeq = [[AESequencerChannelSequence alloc] init];
  _kickChannel.sequence = _kickSeq;
  self.cymbalSeq = [[AESequencerChannelSequence alloc] init];
  _cymbalChannel.sequence = _cymbalSeq;
  self.crashSeq = [[AESequencerChannelSequence alloc] init];
  _crashChannel.sequence = _crashSeq;
  self.tomSeq = [[AESequencerChannelSequence alloc] init];
  _tomChannel.sequence = _tomSeq;
  self.rimshotSeq = [[AESequencerChannelSequence alloc] init];
  _rimshotChannel.sequence = _rimshotSeq;
  self.snareSeq = [[AESequencerChannelSequence alloc] init];
  _snareChannel.sequence = _snareSeq;

  // TODO(ianbarber): Use constant.
  _bpmRotary.value = 120;
  [self updateBpm];
}

- (IBAction)didTapCymbal:(id)sender {
  NSInteger beat = [self.beatSequenceControl.lastSelectedBeat integerValue];
  [_cymbalSeq addBeat:[AESequencerBeat beatWithOnset:kBeatSixteenth * beat]];
  _cymbalChannel.sequence = _cymbalSeq;
  _drumPadView.hidden = YES;
}

- (IBAction)didTapSnare:(id)sender {
  NSInteger beat = [self.beatSequenceControl.lastSelectedBeat integerValue];
  [_snareSeq addBeat:[AESequencerBeat beatWithOnset:kBeatSixteenth * beat]];
  _snareChannel.sequence = _snareSeq;
  _drumPadView.hidden = YES;
}

- (IBAction)didTapTom:(id)sender {
  NSInteger beat = [self.beatSequenceControl.lastSelectedBeat integerValue];
  [_tomSeq addBeat:[AESequencerBeat beatWithOnset:kBeatSixteenth * beat]];
  _tomChannel.sequence = _tomSeq;
  _drumPadView.hidden = YES;
}

- (IBAction)didTapRimshot:(id)sender {
  NSInteger beat = [self.beatSequenceControl.lastSelectedBeat integerValue];
  [_rimshotSeq addBeat:[AESequencerBeat beatWithOnset:kBeatSixteenth * beat]];
  _rimshotChannel.sequence = _rimshotSeq;
  _drumPadView.hidden = YES;
}

- (IBAction)didTapCrash:(id)sender {
  NSInteger beat = [self.beatSequenceControl.lastSelectedBeat integerValue];
  [_crashSeq addBeat:[AESequencerBeat beatWithOnset:kBeatSixteenth * beat]];
  _crashChannel.sequence = _crashSeq;
  _drumPadView.hidden = YES;
}

- (IBAction)didTapKick:(id)sender {
  // TODO(ianbarber): Do removing if this beat already exists.
  NSInteger beat = [self.beatSequenceControl.lastSelectedBeat integerValue];
  [_kickSeq addBeat:[AESequencerBeat beatWithOnset:kBeatSixteenth * beat]];
  _kickChannel.sequence = _kickSeq;
  _drumPadView.hidden = YES;
}

@end
