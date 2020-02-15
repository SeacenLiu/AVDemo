//
//  AUAudioDefine.h
//  AVDemo
//
//  Created by SeacenLiu on 2020/2/2.
//  Copyright © 2020 SeacenLiu. All rights reserved.
//

#ifndef AUAudioDefine_h
#define AUAudioDefine_h

#import <Foundation/Foundation.h>

/** 音频采样数据的采样格式
 *  AUAudioFormatType16Int:
 *      对应kAudioFormatFlagIsSignedInteger，表示每一个采样数据是由16位整数来表示
 *  AUAudioFormatType32Int:
 *      对应kAudioFormatFlagIsSignedInteger，表示每一个采样数据是由32位整数来表示，播放音频时不支持
 *  AudioFormatType32Float:
 *      对应kAudioFormatFlagIsFloat，表示每一个采样数据由32位浮点数来表示
 */
typedef enum : NSUInteger {
    AUAudioFormatType16Int,
    AUAudioFormatType32Int,
    AUAudioFormatType32Float,
} AUAudioFormatType;

/** 音频采样数据在内存中的存储方式
 *  AudioSaveTypePacket:
 *      对应kAudioFormatFlagIsPacked，每个声道数据交叉存储在AudioBufferList的
 *      mBuffers[0]中,如：左声道 右声道 左声道 右声道 ....
 *  AudioSaveTypePlanner:
 *      对应kAudioFormatFlagIsNonInterleaved，表示每个声道数据分开存储在mBuffers[i]中如：
 *      mBuffers[0],左声道 左声道 左声道 左声道
 *      mBuffers[1],右声道 右声道 右声道 右声道
 */
typedef enum : NSUInteger {
    AUAudioSaveTypePacket,
    AUAudioSaveTypePlanner,
} AUAudioSaveType;


/** 音频文件封装格式，
 *  AUAudioFileTypeLPCM
 *      是单纯的裸PCM数据，没有音频属性数据；
 *      裸PCM数据文件不能用AudioFilePlayer和ExtAudioFileRef读写，
 *      只能用NSInputStream和NSOutputStream等流式接口进行读写
 *  AUAudioFileTypeMP3和AUAudioFileTypeM4A
 *      用于存储压缩的音频数据
 *  AUAudioFileTypeWAV和AUAudioFileTypeCAF
 *      用于存储未压缩音频数据
 *  (iOS不支持MP3的编码？一直返回错误)
 */
typedef enum : NSUInteger {
    AUAudioFileTypeLPCM,
    AUAudioFileTypeMP3,
    AUAudioFileTypeM4A,
    AUAudioFileTypeWAV,
    AUAudioFileTypeCAF
} AUAudioFileType;

/** 音频编码格式 */
typedef enum : NSUInteger {
    AUAudioEncodeTypeAAC,
    AUAudioEncodeTypeMP3,
} AUAudioEncodeType;

struct _AudioFormat {
    AUAudioFormatType formatType;
    AUAudioSaveType   saveType;
    UInt32            samplerate;
    UInt32            channels;
};
typedef struct _AudioFormat AUAudioFormat;

#endif /* AUAudioDefine_h */
