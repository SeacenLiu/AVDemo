//
//  AudioToolboxEncoder.h
//  AudioToolboxEncoder
//
//  Created by SeacenLiu on 2019/12/16.
//  Copyright © 2019 SeacenLiu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>

@protocol AudioToolboxEncoderFillDataDelegate <NSObject>

- (UInt32)fillAudioData:(uint8_t*)sampleBuffer
             bufferSize:(UInt32)bufferSize;

- (void)outputAACPakcet:(NSData*)data
  presentationTimeMills:(int64_t)presentationTimeMills
                  error:(NSError*)error;

- (void)onCompletion;

@end

@interface AudioToolboxEncoder : NSObject

- (instancetype)initWithSampleRate:(NSInteger)inputSampleRate
                          channels:(int)channels
                           bitRate:(int)bitRate
                    withADTSHeader:(BOOL)withADTSHeader
                 filleDataDelegate:(id<AudioToolboxEncoderFillDataDelegate>)fillAudioDataDelegate;

@end
