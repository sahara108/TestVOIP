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
#import "SystemSoundHelper.h"
#import "TestAudioOn6s-Swift.h"

@interface ViewController ()<IosAudioControllerDatasource>

@property (nonatomic, strong) IosAudioController *audioUnit;
@property (nonatomic, assign) Float64 audioSampleRate;
@property (nonatomic, assign) Float32 audioBufferDuration;
@property (nonatomic) TPCircularBuffer *outputBuffer;

@property (weak, nonatomic) IBOutlet UIButton *controlButton;
@property (weak, nonatomic) IBOutlet UITextView *consoleLog;
@property (nonatomic, getter=isPlaying) BOOL play;

@property (nonatomic, strong) NSTimer *playTimer;

@property (nonatomic, strong) TestSwiftObject *swiftObject;

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

+(void)requestAudioSession
{
    NSError *error;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionAllowBluetooth error:&error];
    [[AVAudioSession sharedInstance] setMode:AVAudioSessionModeVoiceChat error:&error];
    
    [[AVAudioSession sharedInstance] setActive:YES error:&error];
}

+(void)stopAudioSession
{
    [[AVAudioSession sharedInstance] setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    // Do any additional setup after loading the view, typically from a nib.
    self.audioBufferDuration = 0.02;
    self.audioSampleRate = 48000;
    self.play = NO;

    [self.controlButton setTitle:@"Start" forState:UIControlStateNormal];
    self.consoleLog.editable = NO;
    
    [ViewController requestAudioSession];
    
    self.swiftObject = [TestSwiftObject new];
}

-(void)playSound:(NSString*)name type:(NSString*)type loop:(BOOL)loop viberation:(BOOL)viberation
{
    [[SystemSoundHelper shareInstance] playSoundWithName:name type:type loop:loop withViberation:viberation];
}

- (IBAction)togglePlayPause:(id)sender {
    self.play = !self.play;
    if (self.play) {
        self.controlButton.enabled = NO;
        [ViewController requestAudioSession];
//        [self playSound:@"calling_01" type:@"mp3" loop:true viberation:false];
        [self.swiftObject playSound:@"calling_01" type:@"mp3" loop:true viberation:false];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//            [self playSound:@"cnnection_secured" type:@"mp3" loop:false viberation:false];
            [self.swiftObject playSound:@"cnnection_secured" type:@"mp3" loop:false viberation:false];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self play];
                [self.controlButton setTitle:@"Stop" forState:UIControlStateNormal];
                self.controlButton.enabled = YES;
            });
        });
    }else {
        [self stop];
        [self.controlButton setTitle:@"Start" forState:UIControlStateNormal];
//        [self playSound:@"end_call_01" type:@"mp3" loop:false viberation:false];
        [self.swiftObject playSound:@"end_call_01" type:@"mp3" loop:false viberation:false];
    }
}
- (IBAction)clear:(id)sender {
    self.consoleLog.text = @"";
}

-(void)ensureAudioSessionAreOpen
{
    NSError *error;
    [[AVAudioSession sharedInstance] setActive:NO error:&error];
    [ViewController requestAudioSessionWithOption:self.audioBufferDuration sampleRate:self.audioSampleRate];
}

-(void)play
{
    [self clear:nil];
    
    [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
        if (granted) {
            [self ensureAudioSessionAreOpen];
            self.audioUnit = [IosAudioController graphControllerWithDataSource:self audioBasicStreamFormat:[ViewController stereoFloatInterleavedFormatWithSampleRate:self.audioSampleRate] micrcophoneFormat:[ViewController monoFloatFormatWithSampleRate:self.audioSampleRate]];
            
            self.outputBuffer = malloc(sizeof(TPCircularBuffer));
            TPCircularBufferInit(_outputBuffer, 9600 * sizeof(float) * 1);
            
            self.playTimer = [NSTimer scheduledTimerWithTimeInterval:0.02 target:self selector:@selector(readBuffer:) userInfo:nil repeats:YES];
            [self.playTimer fire];
            
            [self.audioUnit start];
        }
        
    }];

    
}

-(void)stop
{
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    [self.audioUnit stop];
    self.audioUnit = nil;
    
    [ViewController stopAudioSession];
    
    if ([self.playTimer isValid]) {
        [self.playTimer invalidate];
    }
    if (_outputBuffer) {
        TPCircularBufferCleanup(_outputBuffer);
        free(_outputBuffer);
        _outputBuffer = NULL;
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
