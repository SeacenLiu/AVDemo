//
//  AUGraphPlayer.m
//  AVDemo
//
//  Created by SeacenLiu on 2020/1/30.
//  Copyright © 2020 SeacenLiu. All rights reserved.
//

#import "AUGraphPlayer.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import "SCAudioSession.h"

#define ELEMENT_1 1
#define ELEMENT_0 0

@implementation AUGraphPlayer
{
    AUGraph                                     mPlayerGraph;
    
    AUNode                                      mPlayerNode;
    AudioUnit                                   mPlayerUnit;
    
    AUNode                                      mSplitterNode;
    AudioUnit                                   mSplitterUnit;
    
    AUNode                                      mAccMixerNode;
    AudioUnit                                   mAccMixerUnit;
    
    AUNode                                      mVocalMixerNode;
    AudioUnit                                   mVocalMixerUnit;
    
    AUNode                                      mPlayerIONode;
    AudioUnit                                   mPlayerIOUnit;
    
    NSURL*                                      _playPath;
}

#pragma mark - method
- (BOOL)play {
    OSStatus status = AUGraphStart(mPlayerGraph);
    CheckStatus(status, @"Could not start AUGraph", YES);
    return YES;
}

- (void)stop {
    Boolean isRunning = false;
    OSStatus status = AUGraphIsRunning(mPlayerGraph, &isRunning);
    if (isRunning) {
        status = AUGraphStop(mPlayerGraph);
        CheckStatus(status, @"Could not stop AUGraph", YES);
    }
}

#pragma mark - init
- (instancetype)initWithFilePath:(NSString *)path {
    if (self = [super init]) {
        // 初始化 AudioSession
        [[SCAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord];
        // 设置采集率
        [[SCAudioSession sharedInstance] setPreferredSampleRate:44100];
        // 启动 AudioSession
        [[SCAudioSession sharedInstance] setActive:YES];
        // 监听音频路线变化
        [[SCAudioSession sharedInstance] addRouteChangeListener];
        
        // 打断处理
        [self addAudioSessionInterruptedObserver];
        
        // 初始化变量
        _playPath = [NSURL URLWithString:path];
        
        // 初始化音频图
        [self initializePlayGraph];
    }
    return self;
}

#pragma mark - AUGraph initialize
/**
 初始化 PlayGraph
 @discussion
 1. 结构体使用之前，先使用 bzero 或者 memset 清零
 2. xxx
 */
- (void)initializePlayGraph {
    OSStatus status = noErr;
    // 1: 构造 AUGraph
    status = NewAUGraph(&mPlayerGraph);
    CheckStatus(status, @"Could not create a new AUGraph", YES);
    
    // 2: 为 AUGraph 添加结点
    // 2-1: 添加 IONode (音频输入输出结点)
    AudioComponentDescription ioDescription;
    bzero(&ioDescription, sizeof(ioDescription));
    ioDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    ioDescription.componentType = kAudioUnitType_Output;
    ioDescription.componentSubType = kAudioUnitSubType_RemoteIO;
    status = AUGraphAddNode(mPlayerGraph, &ioDescription, &mPlayerIONode);
    CheckStatus(status, @"Could not add I/O node to AUGraph", YES);
    // 2-2: 添加 PlayerNode (播放器结点)
    AudioComponentDescription playerDescription;
    bzero(&playerDescription, sizeof(playerDescription));
    playerDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    playerDescription.componentType = kAudioUnitType_Generator;
    playerDescription.componentSubType = kAudioUnitSubType_AudioFilePlayer;
    status = AUGraphAddNode(mPlayerGraph, &playerDescription, &mPlayerNode);
    CheckStatus(status, @"Could not add Player node to AUGraph", YES);
    // 2-3: 添加 Splitter (格式转化器)
    /**
     An audio unit that provides 2 output buses and 1 input bus. The audio unit
     splits (duplicates) the input signal to the two output buses
     */
    AudioComponentDescription splitterDescription;
    bzero(&splitterDescription, sizeof(splitterDescription));
    splitterDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    splitterDescription.componentType = kAudioUnitType_FormatConverter;
    splitterDescription.componentSubType = kAudioUnitSubType_Splitter;
    status = AUGraphAddNode(mPlayerGraph, &splitterDescription, &mSplitterNode);
    CheckStatus(status, @"Could not add Splitter node to AUGraph", YES);
    // 2-4: 添加两个 Mixer (混音效果器)
    AudioComponentDescription mixerDescription;
    bzero(&mixerDescription, sizeof(mixerDescription));
    mixerDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    mixerDescription.componentType = kAudioUnitType_Mixer;
    mixerDescription.componentSubType = kAudioUnitSubType_MultiChannelMixer;
    status = AUGraphAddNode(mPlayerGraph, &mixerDescription, &mVocalMixerNode);
    CheckStatus(status, @"Could not add VocalMixer node to AUGraph", YES);
    status = AUGraphAddNode(mPlayerGraph, &mixerDescription, &mAccMixerNode);
    CheckStatus(status, @"Could not add AccMixer node to AUGraph", YES);
    
    // 3: 打开 Graph, 只有真正的打开了 Graph 才会实例化每一个 Node
    status = AUGraphOpen(mPlayerGraph);
    CheckStatus(status, @"Could not open AUGraph", YES);
    
    // 4: 获取 AudioUnit
    // 4-1: (*)获取出 IONode 的 AudioUnit
    status = AUGraphNodeInfo(mPlayerGraph, mPlayerIONode, NULL, &mPlayerIOUnit);
    CheckStatus(status, @"Could not retrieve node info for I/O node", YES);
    // 4-2: 获取出 PlayerNode 的 AudioUnit
    status = AUGraphNodeInfo(mPlayerGraph, mPlayerNode, NULL, &mPlayerUnit);
    CheckStatus(status, @"Could not retrieve node info for Player node", YES);
    // 4-3: 获取出 PlayerNode 的 AudioUnit
    status = AUGraphNodeInfo(mPlayerGraph, mSplitterNode, NULL, &mSplitterUnit);
    CheckStatus(status, @"Could not retrieve node info for Splitter node", YES);
    // 4-4: 获取出 VocalMixer 的 AudioUnit
    status = AUGraphNodeInfo(mPlayerGraph, mVocalMixerNode, NULL, &mVocalMixerUnit);
    CheckStatus(status, @"Could not retrieve node info for VocalMixer node", YES);
    // 4-5: 获取出 AccMixer 的 AudioUnit
    status = AUGraphNodeInfo(mPlayerGraph, mAccMixerNode, NULL, &mAccMixerUnit);
    CheckStatus(status, @"Could not retrieve node info for AccMixer node", YES);
    
    // 5: 给 AudioUnit 设置参数
    // 5-1: 将 PlayerIOUnit 和 PlayerUnit 设置为 AudioUnit 的属性
    UInt32 flag = 1;
    status = AudioUnitSetProperty(mPlayerIOUnit,
                                  kAudioOutputUnitProperty_EnableIO,
                                  kAudioUnitScope_Output,
                                  ELEMENT_0,
                                  &flag,
                                  sizeof(flag));
    // 使用 stereoStream 流连通 PlayerIOUnit(输入) 和 PlayerUnit(输出)
    AudioStreamBasicDescription stereoStreamFormat; // 立体声流格式
    UInt32 bytesPerSample = sizeof(Float32);
    bzero(&stereoStreamFormat, sizeof(stereoStreamFormat));
    stereoStreamFormat.mFormatID          = kAudioFormatLinearPCM;
    stereoStreamFormat.mFormatFlags       = kAudioFormatFlagsNativeFloatPacked | kAudioFormatFlagIsNonInterleaved;
    stereoStreamFormat.mBytesPerPacket    = bytesPerSample;
    stereoStreamFormat.mFramesPerPacket   = 1;
    stereoStreamFormat.mBytesPerFrame     = bytesPerSample;
    stereoStreamFormat.mChannelsPerFrame  = 2;                    // 2 indicates stereo
    stereoStreamFormat.mBitsPerChannel    = 8 * bytesPerSample;
    stereoStreamFormat.mSampleRate        = 48000.0;
    status = AudioUnitSetProperty(mPlayerIOUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  ELEMENT_0,
                                  &stereoStreamFormat,
                                  sizeof(stereoStreamFormat));
    CheckStatus(status, @"set remote IO output element stream format ", YES);
    status = AudioUnitSetProperty(mPlayerUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Output,
                                  ELEMENT_0,
                                  &stereoStreamFormat,
                                  sizeof (stereoStreamFormat));
    CheckStatus(status, @"Could not Set StreamFormat for Player Unit", YES);
    // 5-2: 配置 Splitter 的属性 (输入输出都需要配置)
    status = AudioUnitSetProperty(mSplitterUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Output,
                                  ELEMENT_0,
                                  &stereoStreamFormat,
                                  sizeof(stereoStreamFormat));
    CheckStatus(status, @"Could not Set StreamFormat for Splitter Unit", YES);
    status = AudioUnitSetProperty(mSplitterUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  ELEMENT_0,
                                  &stereoStreamFormat,
                                  sizeof(stereoStreamFormat));
    CheckStatus(status, @"Could not Set StreamFormat for Splitter Unit", YES);
    
    // 5-3: 配置 VocalMixerUnit 的属性 (设置输入输出和输入元素数)
    status = AudioUnitSetProperty(mVocalMixerUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Output,
                                  ELEMENT_0,
                                  &stereoStreamFormat,
                                  sizeof(stereoStreamFormat));
    CheckStatus(status, @"Could not Set StreamFormat for VocalMixer Unit", YES);
    status = AudioUnitSetProperty(mVocalMixerUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  ELEMENT_0,
                                  &stereoStreamFormat,
                                  sizeof(stereoStreamFormat));
    CheckStatus(status, @"Could not Set StreamFormat for VocalMixer Unit", YES);
    int mixerElementCount = 1;
    status = AudioUnitSetProperty(mVocalMixerUnit,
                                  kAudioUnitProperty_ElementCount,
                                  kAudioUnitScope_Input,
                                  ELEMENT_0,
                                  &mixerElementCount,
                                  sizeof(mixerElementCount));
    // 5-4: 配置 AccMixerUnit 的属性 (设置输入输出和输入元素数)
    status = AudioUnitSetProperty(mAccMixerUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Output,
                                  ELEMENT_0,
                                  &stereoStreamFormat,
                                  sizeof(stereoStreamFormat));
    CheckStatus(status, @"Could not Set StreamFormat for AccMixer Unit", YES);
    status = AudioUnitSetProperty(mAccMixerUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  ELEMENT_0,
                                  &stereoStreamFormat,
                                  sizeof(stereoStreamFormat));
    CheckStatus(status, @"Could not Set StreamFormat for AccMixer Unit", YES);
    mixerElementCount = 2;
    status = AudioUnitSetProperty(mAccMixerUnit,
                                  kAudioUnitProperty_ElementCount,
                                  kAudioUnitScope_Input,
                                  ELEMENT_0,
                                  &mixerElementCount,
                                  sizeof(mixerElementCount));
    
    [self setInputSource:NO];
    
    // 6: 连接起Node来 connect a node's output to a node's input
    AUGraphConnectNodeInput(mPlayerGraph, mPlayerNode, ELEMENT_0, mSplitterNode, ELEMENT_0);
    CheckStatus(status, @"Player Node Connect To IONode", YES);
    AUGraphConnectNodeInput(mPlayerGraph, mSplitterNode, ELEMENT_0, mVocalMixerNode, ELEMENT_0);
    CheckStatus(status, @"Player Node Connect To IONode", YES);
    
    AUGraphConnectNodeInput(mPlayerGraph, mSplitterNode, ELEMENT_1, mAccMixerNode, ELEMENT_1);
    CheckStatus(status, @"Player Node Connect To IONode", YES);
    
    AUGraphConnectNodeInput(mPlayerGraph, mVocalMixerNode, ELEMENT_0, mAccMixerNode, ELEMENT_0);
    CheckStatus(status, @"Player Node Connect To IONode", YES);
    
    AUGraphConnectNodeInput(mPlayerGraph, mAccMixerNode, ELEMENT_0, mPlayerIONode, ELEMENT_0);
    CheckStatus(status, @"Player Node Connect To IONode", YES);
    
    // 7 :初始化Graph
    status = AUGraphInitialize(mPlayerGraph);
    CheckStatus(status, @"Couldn't Initialize the graph", YES);
    // 8: 显示Graph结构
    CAShow(mPlayerGraph);
    // 9: 只有对Graph进行Initialize之后才可以设置AudioPlayer的参数
    // 配置 AudioPlayer 读取文件数据
    [self setUpFilePlayer];
}

- (void)setUpFilePlayer {
    OSStatus status = noErr;
    AudioFileID musicFile;
    CFURLRef songURL = (__bridge  CFURLRef) _playPath;
    // 打开输入的音频文件
    status = AudioFileOpenURL(songURL, kAudioFileReadPermission, 0, &musicFile);
    CheckStatus(status, @"Open AudioFile... ", YES);
    
    // 在全局域的输出元素中设置播放器单元目标文件
    status = AudioUnitSetProperty(
                                  mPlayerUnit,
                                  kAudioUnitProperty_ScheduledFileIDs,
                                  kAudioUnitScope_Global,
                                  ELEMENT_0,
                                  &musicFile,
                                  sizeof(musicFile)
                                  );
    CheckStatus(status, @"Tell AudioFile Player Unit Load Which File... ", YES);
    
    // 通过音频文件获取音频数据流的格式
    AudioStreamBasicDescription fileASBD;
    UInt32 propSize = sizeof(fileASBD);
    status = AudioFileGetProperty(musicFile,
                                  kAudioFilePropertyDataFormat,
                                  &propSize,
                                  &fileASBD);
    CheckStatus(status, @"get the audio data format from the file... ", YES);
    
    // 通过音频文件获取音频数据包的数量
    UInt64 nPackets;
    UInt32 propsize = sizeof(nPackets);
    AudioFileGetProperty(musicFile,
                         kAudioFilePropertyAudioDataPacketCount,
                         &propsize,
                         &nPackets);
    
    // 告知文件播放单元从0开始播放整个文件
    ScheduledAudioFileRegion rgn;
    memset (&rgn.mTimeStamp, 0, sizeof(rgn.mTimeStamp));
    rgn.mTimeStamp.mFlags = kAudioTimeStampSampleTimeValid;
    rgn.mTimeStamp.mSampleTime = 0;
    rgn.mCompletionProc = NULL;
    rgn.mCompletionProcUserData = NULL;
    rgn.mAudioFile = musicFile;
    rgn.mLoopCount = 2;
    rgn.mStartFrame = 0;
    rgn.mFramesToPlay = (UInt32)nPackets * fileASBD.mFramesPerPacket;
    status = AudioUnitSetProperty(mPlayerUnit,
                                  kAudioUnitProperty_ScheduledFileRegion,
                                  kAudioUnitScope_Global,
                                  ELEMENT_0,
                                  &rgn,
                                  sizeof(rgn));
    CheckStatus(status, @"Set Region... ", YES);
    
    // 设置文件播放单元参数为默认值
    UInt32 defaultVal = 0;
    status = AudioUnitSetProperty(mPlayerUnit,
                                  kAudioUnitProperty_ScheduledFilePrime,
                                  kAudioUnitScope_Global,
                                  ELEMENT_0,
                                  &defaultVal,
                                  sizeof(defaultVal));
    CheckStatus(status, @"Prime Player Unit With Default Value... ", YES);
    
    // 设置何时开始播放(播放模式)(-1 sample time means next render cycle)
    AudioTimeStamp startTime;
    memset (&startTime, 0, sizeof(startTime));
    startTime.mFlags = kAudioTimeStampSampleTimeValid;
    startTime.mSampleTime = -1;
    status = AudioUnitSetProperty(mPlayerUnit,
                                  kAudioUnitProperty_ScheduleStartTimeStamp,
                                  kAudioUnitScope_Global,
                                  ELEMENT_0,
                                  &startTime,
                                  sizeof(startTime));
    CheckStatus(status, @"set Player Unit Start Time... ", YES);
}

- (void)setInputSource:(BOOL)isAcc {
    OSStatus status;
    // 设置 VocalMixerUnit 输入域输出元素的音量 为 1
    status = AudioUnitSetParameter(mVocalMixerUnit,
                                   kMultiChannelMixerParam_Volume,
                                   kAudioUnitScope_Input,
                                   ELEMENT_0,
                                   1.0,
                                   0);
    CheckStatus(status, @"set parameter fail", YES);
    
    
    if (isAcc) {
        // 设置 AccMixerUnit 输入域输出元素的音量为 0.1
        status = AudioUnitSetParameter(mAccMixerUnit,
                                       kMultiChannelMixerParam_Volume,
                                       kAudioUnitScope_Input,
                                       ELEMENT_0,
                                       0.1,
                                       0);
        CheckStatus(status, @"set parameter fail", YES);
        // 设置 AccMixerUnit 输入域输入元素的音量为 1
        status = AudioUnitSetParameter(mAccMixerUnit,
                                       kMultiChannelMixerParam_Volume,
                                       kAudioUnitScope_Input,
                                       ELEMENT_1,
                                       1,
                                       0);
        CheckStatus(status, @"set parameter fail", YES);
    } else {
        // 设置 AccMixerUnit 输入域输出元素的音量为 1
        status = AudioUnitSetParameter(mAccMixerUnit,
                                       kMultiChannelMixerParam_Volume,
                                       kAudioUnitScope_Input,
                                       ELEMENT_0,
                                       1,
                                       0);
        CheckStatus(status, @"set parameter fail", YES);
        // 设置 AccMixerUnit 输入域输入元素的音量为 0.1
        status = AudioUnitSetParameter(mAccMixerUnit,
                                       kMultiChannelMixerParam_Volume,
                                       kAudioUnitScope_Input,
                                       ELEMENT_1,
                                       0.1,
                                       0);
        CheckStatus(status, @"set parameter fail", YES);
    }
    // 打印查看当前值
    // 获取 VocalMixerUnit 输入域输出元素的音量
    AudioUnitParameterValue value;
    status = AudioUnitGetParameter(mVocalMixerUnit,
                                   kMultiChannelMixerParam_Volume,
                                   kAudioUnitScope_Input,
                                   ELEMENT_0,
                                   &value);
    CheckStatus(status, @"get parameter fail", YES);
    NSLog(@"Vocal Mixer %lf", value);
    
    // 获取 AccMixerUnit 输入域输出元素的音量
    status = AudioUnitGetParameter(mAccMixerUnit,
                                   kMultiChannelMixerParam_Volume,
                                   kAudioUnitScope_Input,
                                   ELEMENT_0,
                                   &value);
    CheckStatus(status, @"get parameter fail", YES);
    NSLog(@"Acc Mixer 0 %lf", value);
    
    // 获取 AccMixerUnit 输入域输入元素的音量
    status = AudioUnitGetParameter(mAccMixerUnit,
                                   kMultiChannelMixerParam_Volume,
                                   kAudioUnitScope_Input,
                                   ELEMENT_1,
                                   &value);
    CheckStatus(status, @"get parameter fail", YES);
    NSLog(@"Acc Mixer 1 %lf", value);
}


#pragma mark - notification observer
- (void)addAudioSessionInterruptedObserver {
    [self removeAudioSessionInterruptedObserver];
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(onNotificationAudioInterrupted:)
     name:AVAudioSessionInterruptionNotification
     object:[AVAudioSession sharedInstance]];
}

- (void)removeAudioSessionInterruptedObserver {
    [[NSNotificationCenter defaultCenter]
     removeObserver:self
     name:AVAudioSessionInterruptionNotification
     object:nil];
}

- (void)onNotificationAudioInterrupted:(NSNotification *)sender {
    AVAudioSessionInterruptionType interruptionType = [[[sender userInfo] objectForKey:AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];
    switch (interruptionType) {
        case AVAudioSessionInterruptionTypeBegan:
            [self stop];
            break;
        case AVAudioSessionInterruptionTypeEnded:
            [self play];
            break;
        default:
            break;
    }
}

@end
