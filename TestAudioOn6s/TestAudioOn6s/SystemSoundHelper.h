//
//  SystemSoundHelper.h
//  Fabric
//
//  Created by Long Pham on 03/07/2015.
//  Copyright (c) 2015 io.fabric. All rights reserved.
//


#import <UIKit/UIKit.h>
@import AudioToolbox;

@interface SystemSoundHelper : NSObject
//- (AudioServicesSystemSoundCompletionProc) completionHandler ;

+ (instancetype) shareInstance;
void soundFinished (SystemSoundID snd, void* context);

//- (void) setRepeat: (BOOL) isOn;

- (void)playSoundWithName:(NSString *)soundName type: (NSString *)type loop: (BOOL)isLoop;
- (void)playSoundWithName:(NSString *)soundName type: (NSString *)type loop: (BOOL)isLoop withViberation:(BOOL)option;
- (void)playSoundWithName:(NSString *)soundName type: (NSString *)type loop: (BOOL)isLoop withViberation:(BOOL)option withCompletion:(void(^)())completion;
- (void) startVibration: (BOOL)isLoop;
- (void) stopVibration;
- (void) stopCurrentSound;

@end