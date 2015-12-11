//
//  ViewController.m
//  TestAudioOn6s
//
//  Created by Nguyen Tuan on 12/11/15.
//  Copyright © 2015 withfabric.io. All rights reserved.
//

#import "ViewController.h"
#import "IosAudioController.h"
#import <AVFoundation/AVFoundation.h>
#import "TPCircularBuffer.h"

@interface ViewController ()<IosAudioControllerDatasource>

@property (nonatomic, strong) IosAudioController *audioUnit;
@property (nonatomic, assign) Float64 audioSampleRate;
@property (nonatomic, assign) Float32 audioBufferDuration;
@property (nonatomic) TPCircularBuffer *outputBuffer;

@property (weak, nonatomic) IBOutlet UIButton *controlButton;
@property (weak, nonatomic) IBOutlet UITextView *consoleLog;
@property (nonatomic, getter=isPlaying) BOOL play;

@property (nonatomic, strong) NSTimer *playTimer;

@end

@implementation ViewController

+(AudioStreamBasicDescription)stereoFloatInterleavedFormatWithSampleRate:(Float64)sampleRate
{
    AudioStreamBasicDescription asbd;
    UInt32 floatByteSize   = sizeof(float);
    asbd.mChannelsPerFrame = 2;
    asbd.mBitsPerChannel   = 8 * floatByteSize;
    asbd.mBytesPerFrame    = asbd.mChannelsPerFrame * floatByteSize;
    asbd.mBytesPerPacket   = asbd.mChannelsPerFrame * floatByteSize;
    asbd.mFormatFlags      = kAudioFormatFlagIsPacked|kAudioFormatFlagIsFloat;
    asbd.mFormatID         = kAudioFormatLinearPCM;
    asbd.mFramesPerPacket  = 1;
    asbd.mSampleRate       = sampleRate;
    return asbd;
}

+(AudioStreamBasicDescription)monoFloatFormatWithSampleRate:(Float64)sampleRate
{
    AudioStreamBasicDescription asbd;
    UInt32 byteSize = sizeof(float);
    asbd.mBitsPerChannel   = 8 * byteSize;
    asbd.mBytesPerFrame    = byteSize;
    asbd.mBytesPerPacket   = byteSize;
    asbd.mChannelsPerFrame = 1;
    asbd.mFormatFlags      = kAudioFormatFlagIsPacked|kAudioFormatFlagIsFloat;
    asbd.mFormatID         = kAudioFormatLinearPCM;
    asbd.mFramesPerPacket  = 1;
    asbd.mSampleRate       = sampleRate;
    return asbd;
}

+(void)requestAudioSessionWithOption:(double)bufferDuration sampleRate:(Float64)sampleRate
{
    NSError *error;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionAllowBluetooth error:&error];
    [[AVAudioSession sharedInstance] setMode:AVAudioSessionModeVoiceChat error:&error];
    
    [[AVAudioSession sharedInstance] setPreferredIOBufferDuration:bufferDuration error:&error];
    if (error) {
        
    }
    
    [[AVAudioSession sharedInstance] setPreferredSampleRate:sampleRate error:&error];
    if (error) {
        
    }
    
    [[AVAudioSession sharedInstance] setActive:YES error:&error];
}

+(void)stopAudioSession
{
    [[AVAudioSession sharedInstance] setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.audioBufferDuration = 0.02;
    self.audioSampleRate = 48000;
    self.play = NO;

    [self.controlButton setTitle:@"Start" forState:UIControlStateNormal];
    self.consoleLog.editable = NO;
}

- (IBAction)togglePlayPause:(id)sender {
    self.play = !self.play;
    if (self.play) {
        [self play];
        [self.controlButton setTitle:@"Stop" forState:UIControlStateNormal];
    }else {
        [self stop];
        [self.controlButton setTitle:@"Start" forState:UIControlStateNormal];
    }
}
- (IBAction)clear:(id)sender {
    self.consoleLog.text = @"";
}

-(void)play
{
    [self clear:nil];
    [ViewController requestAudioSessionWithOption:self.audioBufferDuration sampleRate:self.audioSampleRate];
    self.audioUnit = [IosAudioController graphControllerWithDataSource:self audioBasicStreamFormat:[ViewController stereoFloatInterleavedFormatWithSampleRate:self.audioSampleRate] micrcophoneFormat:[ViewController monoFloatFormatWithSampleRate:self.audioSampleRate]];
    
    self.outputBuffer = malloc(sizeof(TPCircularBuffer));
    TPCircularBufferInit(_outputBuffer, 9600 * sizeof(float) * 1);
    
    self.playTimer = [NSTimer scheduledTimerWithTimeInterval:0.02 target:self selector:@selector(readBuffer:) userInfo:nil repeats:YES];
    [self.playTimer fire];
    
    [self.audioUnit start];
}

-(void)stop
{
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    [self.audioUnit stop];
    self.audioUnit = nil;
    
    if (_outputBuffer) {
        TPCircularBufferCleanup(_outputBuffer);
        free(_outputBuffer);
    }
    
    [ViewController stopAudioSession];
    
    if ([self.playTimer isValid]) {
        [self.playTimer invalidate];
    }
}

-(void)readBuffer:(id)timer
{
    //read data
    float val = drand48();
    for (int i = 0; i<1000; i++) {
        TPCircularBufferProduceBytes(_outputBuffer, &val, sizeof(float));
        val = drand48();
    }
}

#pragma mark IosAudioDelegate

-(TPCircularBuffer *)outputShouldUseCircularBuffer:(IosAudioController *)output
{
    return _outputBuffer;
}

-(void)microphone:(IosAudioController *)microphone hasAudioStreamBasicDescription:(AudioStreamBasicDescription)audioStreamBasicDescription
{
    
}

-(void)microphone:(IosAudioController *)microphone hasBufferList:(AudioBufferList *)bufferList withBufferSize:(UInt32)bufferSize withNumberOfChannels:(UInt32)numberOfChannels
{
    float *bb = (float*)bufferList->mBuffers[0].mData;
    NSString *text = self.consoleLog.text;
    if (!text) {
        text = @"";
    }
    
    text = [NSString stringWithFormat:@"%@:%f",text,bb[0]];
    dispatch_async(dispatch_get_main_queue(), ^{
        self.consoleLog.text = text;
    });
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
