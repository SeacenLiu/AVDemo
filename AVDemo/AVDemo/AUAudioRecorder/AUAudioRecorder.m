//
//  AUAudioRecorder.m
//  AVDemo
//
//  Created by SeacenLiu on 2020/2/1.
//  Copyright © 2020 SeacenLiu. All rights reserved.
//

#import "AUAudioRecorder.h"
#import "SCAudioSession.h"
#import "AUAudioRecorder+Interruption.h"
#import "AUExtAudioFile+Write.h"
#import "NSString+Path.h"

/** 主要使用的音频流格式
 * Sample Rate:              44100
 * Format ID:                 lpcm
 * Format Flags:                 C
 * Bytes per Packet:             4
 * Frames per Packet:            1
 * Bytes per Frame:              4
 * Channels per Frame:           2
 * Bits per Channel:            16
 * Reserved:                     0
 */

static const AudioUnitElement inputElement = 1;
static const AudioUnitElement outputElement = 0;

@interface AUAudioRecorder ()

@property (nonatomic, copy)   NSString*          filePath;
@property (nonatomic, assign) Float64            sampleRate;
@property (nonatomic, assign) UInt32             channels;

@property (nonatomic, assign) AUGraph            auGraph;

@property (nonatomic, assign) AUNode             ioNode;
@property (nonatomic, assign) AudioUnit          ioUnit;

@end

#define BufferList_cache_size (1024*10*5)
@implementation AUAudioRecorder

@end
