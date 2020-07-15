//
//  AudioUnitHelp.h
//  AVDemo
//
//  Created by SeacenLiu on 2020/1/30.
//  Copyright © 2020 SeacenLiu. All rights reserved.
//

#ifndef AudioUnitHelp_h
#define AudioUnitHelp_h

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>

#pragma mark - AudioComponentDescription Help
/** 创建指定音频组件描述 */
static AudioComponentDescription comDesc(OSType type,
                                  OSType subType,
                                  OSType manufuture,
                                  UInt32 flags,
                                  UInt32 flagsMask) {
    AudioComponentDescription acd;
    acd.componentType = type;
    acd.componentSubType = subType;
    acd.componentManufacturer = manufuture;
    acd.componentFlags = flags;
    acd.componentFlagsMask = flagsMask;
    return acd;
}

#pragma mark - AudioStreamBasicDescription Help
/** 创建指定的线性PCM数据流格式
 * 数据量描述关注顺序: Packet(包数) > Frames(帧数) > Channels(通道数) > Bytes(字节数) > Bits(二进制数)
 *
 * 每一个通道的字节数(位深) = Channels(通道数) * Bytes(字节数) * Bits(二进制数)
 *
 * flags: 采样格式及存储方式
 * rate: 采样率
 * channels: 声道数
 * bytesPerChannel: 每一个声道的字节数
 */
static AudioStreamBasicDescription linearPCMStreamDes(AudioFormatFlags flags,
                                                      Float64 rate,
                                                      UInt32 channels,
                                                      UInt32 bytesPerChannel) {
    UInt32 bitsPerByte = 8; // 1个字节 = 8个二进制位
    
    /*
     * Packet 数据(kAudioFormatFlagIsPacked): 各个声道数据依次存储在mBuffers[0]中
     * Planner 数据(kAudioFormatFlagIsNonInterleaved): 每个声道数据分别存储在mBuffers[0],...,mBuffers[i]中
     */
    BOOL isPlanner = flags & kAudioFormatFlagIsNonInterleaved;
    
    AudioStreamBasicDescription asbd;
    bzero(&asbd, sizeof(asbd));
    asbd.mSampleRate = rate;                    // 采样率
    asbd.mFormatID = kAudioFormatLinearPCM;     // 编码格式
    asbd.mFormatFlags = flags;                  // 采样格式及存储方式
    asbd.mBitsPerChannel = bitsPerByte * bytesPerChannel; // 位深
    asbd.mChannelsPerFrame = (UInt32)channels;  // 声道数
    if (isPlanner) { // planner格式: 每一帧只是包含一个Channel
        asbd.mBytesPerFrame = bytesPerChannel;  // 每一帧的字节数
    } else { // packet格式: 每一帧包含多个Channel
        asbd.mBytesPerFrame = (UInt32)channels * bytesPerChannel; // 每一帧的字节数
    }
    // kAudioFormatLinearPCM编码格式的packet中只有一个frame
    asbd.mFramesPerPacket = 1;                  // 每一个包的帧数
    asbd.mBytesPerPacket = asbd.mFramesPerPacket * asbd.mBytesPerFrame; // 每一个包的字节数
    
    return asbd;
}

static bool CheckASBDisPlanner(AudioStreamBasicDescription asbd) {
    return asbd.mFormatFlags & kAudioFormatFlagIsNonInterleaved;
}

/** 打印音频流格式 */
static void printAudioStreamFormat(AudioStreamBasicDescription asbd) {
    char formatID[5];
    UInt32 mFormatID = CFSwapInt32HostToBig(asbd.mFormatID);
    bcopy (&mFormatID, formatID, 4);
    formatID[4] = '\0';
    printf("Sample Rate:         %10.0f\n",  asbd.mSampleRate);
    printf("Format ID:           %10s\n",    formatID);
    printf("Format Flags:        %10X\n",    (unsigned int)asbd.mFormatFlags);
    printf("Bytes per Packet:    %10d\n",    (unsigned int)asbd.mBytesPerPacket);
    printf("Frames per Packet:   %10d\n",    (unsigned int)asbd.mFramesPerPacket);
    printf("Bytes per Frame:     %10d\n",    (unsigned int)asbd.mBytesPerFrame);
    printf("Channels per Frame:  %10d\n",    (unsigned int)asbd.mChannelsPerFrame);
    printf("Bits per Channel:    %10d\n",    (unsigned int)asbd.mBitsPerChannel);
    printf("Reserved:            %10d\n",    (unsigned int)asbd.mReserved);
    printf("\n");
}

#pragma mark - Commom
/** 检查 OSStatus */
static void CheckStatus(OSStatus status, NSString *message, BOOL fatal) {
    if(status != noErr) {
        char fourCC[16];
        *(UInt32 *)fourCC = CFSwapInt32HostToBig(status);
        fourCC[4] = '\0';
        
        if (isprint(fourCC[0]) &&
            isprint(fourCC[1]) &&
            isprint(fourCC[2]) &&
            isprint(fourCC[3]))
            NSLog(@"%@: %s", message, fourCC);
        else
            NSLog(@"%@: %d", message, (int)status);
        
        if (fatal)
            exit(-1);
    }
}

#pragma mark - Buffer List Help
static AudioBufferList* CreateBufferList(UInt32 channels,
                                         BOOL isPlanner,
                                         UInt32 cacheSize) {
    AudioBufferList *bufferList = (AudioBufferList *)malloc(sizeof(AudioBufferList) + (channels - 1) * sizeof(AudioBuffer));
    bufferList->mNumberBuffers = isPlanner ? (UInt32)channels : 1;
    for (NSInteger i = 0; i < channels; ++i) {
        bufferList->mBuffers[i].mData = malloc(cacheSize);
        bufferList->mBuffers[i].mDataByteSize = cacheSize;
    }
    return bufferList;
}

static void CopyInterleavedBufferList(AudioBufferList *dst,
                                      AudioBufferList *src) {
    dst->mNumberBuffers = src->mNumberBuffers;
    memcpy(dst->mBuffers[0].mData, src->mBuffers[0].mData, src->mBuffers[0].mDataByteSize);
    dst->mBuffers[0].mDataByteSize = src->mBuffers[0].mDataByteSize;
}

static void SilenceInterleavedBufferList(AudioBufferList *bufferList) {
     UInt32 numberBuffers = bufferList->mNumberBuffers;
    for (int i = 0; i < numberBuffers; ++i) {
        AudioBuffer ab = bufferList->mBuffers[i];
        memset(ab.mData, 0, ab.mDataByteSize);
    }
}

static void DestroyBufferList(AudioBufferList *bufferList) {
    if (bufferList != NULL) {
        for (int i = 0; i < bufferList->mNumberBuffers; ++i) {
            if (bufferList->mBuffers[i].mData != NULL) {
                free(bufferList->mBuffers[i].mData);
                bufferList->mBuffers[i].mData = NULL;
            }
        }
        free(bufferList);
        bufferList = NULL;
    }
}

#endif /* AudioUnitHelp_h */