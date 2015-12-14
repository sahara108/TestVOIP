//
//  SystemSoundHelper.m
//  Fabric
//
//  Created by Long Pham on 03/07/2015.
//  Copyright (c) 2015 io.fabric. All rights reserved.
//

#import "SystemSoundHelper.h"
#import <AVFoundation/AVFoundation.h>

@interface SystemSoundHelper()
@property (nonatomic) SystemSoundID currentSoundId;
@property (nonatomic, assign) BOOL repeat;
@property (nonatomic, assign) BOOL viberationOn;
@property (nonatomic) NSTimer * timer;

@property (nonatomic, strong) AVPlayer *player;

@property (nonatomic, copy) void (^completion)();

@end

@implementation SystemSoundHelper

static dispatch_once_t onceToken;

static SystemSoundHelper *sharedInstance = nil;

+(instancetype)shareInstance
{
    dispatch_once(&onceToken, ^{
        sharedInstance = [[[self class] alloc] init];
    });
    return sharedInstance;
}

void soundFinished (SystemSoundID snd, void* context) {
    
    SystemSoundHelper *soundHelper = (__bridge SystemSoundHelper*)context;
    if (soundHelper.repeat) {
        [soundHelper playSoundId:snd];
    }else {
        AudioServicesRemoveSystemSoundCompletion(snd);
        AudioServicesDisposeSystemSoundID(snd);
        soundHelper.currentSoundId = 0;
        if (soundHelper.completion) {
            soundHelper.completion();
            soundHelper.completion = nil;
        }
    }
}

- (void)playerItemDidReachEnd:(NSNotification *)notification {
    AVPlayerItem *p = [notification object];
    [p seekToTime:kCMTimeZero];
}

- (void)playSoundWithName:(NSString *)soundName type: (NSString *)type loop: (BOOL)isLoop{
    [self playSoundWithName:soundName type:type loop:isLoop withViberation:NO];
}

-(void)playSoundWithName:(NSString *)soundName type:(NSString *)type loop:(BOOL)isLoop withViberation:(BOOL)option
{
    [self playSoundWithName:soundName type:type loop:isLoop withViberation:option withCompletion:nil];
}

-(void)playSoundWithName:(NSString *)soundName type:(NSString *)type loop:(BOOL)isLoop withViberation:(BOOL)option withCompletion:(void (^)())completion
{
    //    soundName = @"securing_connection";
    [self stopCurrentSound];
    self.completion = completion;
    SystemSoundID mySound  = 0;
    CFURLRef soundURL = (__bridge CFURLRef)([[NSBundle mainBundle] URLForResource:soundName withExtension:type]);
    AudioServicesCreateSystemSoundID(soundURL, &mySound);
    UInt32 flag = 0;
    AudioServicesSetProperty(kAudioServicesPropertyIsUISound,
                             sizeof(UInt32),
                             &mySound,
                             sizeof(UInt32),
                             &flag);
    
    self.repeat = isLoop;
    self.viberationOn = option;
    self.currentSoundId = mySound;
    
    AudioServicesAddSystemSoundCompletion(mySound, NULL, NULL, &soundFinished, (__bridge void *)(self));
    [self playSoundId:mySound];
}

-(void)playSoundId:(SystemSoundID)soundId
{
    if (self.viberationOn) {
        AudioServicesPlayAlertSound(soundId);
    }else {
        AudioServicesPlaySystemSound(soundId);
    }
}

- (void)startVibration:(BOOL)isLoop {
//    if (_timer == nil) {
//        _timer = [NSTimer scheduledTimerWithTimeInterval:3 target:self selector:@selector(playVibration) userInfo:nil repeats:isLoop];
//        AudioServicesPlayAlertSound(kSystemSoundID_Vibrate);
//    }
}

- (void)stopVibration {
//    if (_timer != nil) {
//        [_timer invalidate];
//        _timer = nil;
//    }
}

- (void) playVibration {
//    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
    AudioServicesPlayAlertSound(kSystemSoundID_Vibrate);
}

//-(void)vibe:(id)sender {
//    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
//}



- (void)stopCurrentSound {
    if (self.repeat) {
        [[NSNotificationCenter defaultCenter] removeObserver:self];
    }
    self.repeat = NO;
    if (self.player) {
        [self.player pause];
    }
    
    if (self.completion) {
        self.completion = nil;
    }
    
    if (self.currentSoundId != 0) {
        AudioServicesRemoveSystemSoundCompletion(self.currentSoundId);
        AudioServicesDisposeSystemSoundID(self.currentSoundId);
        self.currentSoundId = 0;
    }
}
@end