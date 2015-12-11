//
//  IosAudioController.h
//  Aruts
//
//  Created by Simon Epskamp on 10/11/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "TPCircularBuffer.h"

#ifndef max
#define max( a, b ) ( ((a) > (b)) ? (a) : (b) )
#endif

#ifndef min
#define min( a, b ) ( ((a) < (b)) ? (a) : (b) )
#endif

@class IosAudioController;

@protocol IosAudioControllerDatasource <NSObject>

-(TPCircularBuffer *)outputShouldUseCircularBuffer:(IosAudioController *)output;

-(void)microphone:(IosAudioController *)microphone hasBufferList:(AudioBufferList *)bufferList withBufferSize:(UInt32)bufferSize withNumberOfChannels:(UInt32)numberOfChannels;
-(void)microphone:(IosAudioController *)microphone hasAudioStreamBasicDescription:(AudioStreamBasicDescription)audioStreamBasicDescription;

@end

@interface IosAudioController : NSObject {
}

@property (nonatomic, assign) id<IosAudioControllerDatasource> dataSource;

+(instancetype)graphControllerWithDataSource:(id<IosAudioControllerDatasource>)datasource audioBasicStreamFormat:(AudioStreamBasicDescription)speakerFormat micrcophoneFormat:(AudioStreamBasicDescription)micFormat;

- (void) start;
- (void) stop;

-(void)setMute:(BOOL)on;
-(BOOL)isMuting;

@end

// setup a global iosAudio variable, accessible everywhere
extern IosAudioController* iosAudio;