//
//  SCAudioOutput.h
//  AudioPlayer
//
//  Created by SeacenLiu on 2019/11/14.
//  Copyright © 2019 SeacenLiu. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol SCFillDataDelegate <NSObject>

/// 填充音频数据
/// @param sampleBuffer 音频数据
/// @param frameNum 帧数
/// @param channels 声道数
- (NSInteger)fillAudioData:(SInt16*)sampleBuffer
                  numFrames:(NSInteger)frameNum
                numChannels:(NSInteger)channels;

@end

@interface SCAudioOutput : NSObject

@property (nonatomic, assign) Float64 sampleRate;
@property (nonatomic, assign) Float64 channels;

- (instancetype)initWithChannels:(NSInteger)channels
                      sampleRate:(NSInteger)sampleRate
                  bytesPerSample:(NSInteger) bytePerSample
               filleDataDelegate:(id<SCFillDataDelegate>) fillAudioDataDelegate;

- (BOOL) play;
- (BOOL) stop;

@end
