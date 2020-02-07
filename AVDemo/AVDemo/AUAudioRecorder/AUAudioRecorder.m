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
#import "AUExtAudioFile+Read.h"
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
@property (nonatomic, assign) AUNode             playerNode;
@property (nonatomic, assign) AudioUnit          playerUnit;
@property (nonatomic, assign) AUNode             mixerNode;
@property (nonatomic, assign) AudioUnit          mixerUnit;
@property (nonatomic, assign) AUNode             convertNode;
@property (nonatomic, assign) AudioUnit          convertUnit;

@end

#define BufferList_cache_size (1024*10*5)
@implementation AUAudioRecorder
{
    AUExtAudioFile*  _dataWriter;
    NSString*        _backgroundPath;
    
    AudioBufferList* _mixbufferList;
    AudioBufferList* _bgmBufferList;
}
#pragma mark - life cycle
- (instancetype)initWithPath:(NSString*)path {
    if (self = [self init]) {
        // 属性初始化
        _filePath = path;
        _sampleRate = 44100.0;
        _channels = 2;
        
        _backgroundPath = [NSString bundlePath:@"background.mp3"];
        self.enablePlayWhenRecord = NO;
        self.enableBgm = YES;
        
        _mixbufferList = CreateBufferList(2, NO, BufferList_cache_size);
        _bgmBufferList = CreateBufferList(2, NO, BufferList_cache_size);
        
        // 音频会话设置
        [[SCAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord];
        [[SCAudioSession sharedInstance] setPreferredSampleRate:_sampleRate];
        [[SCAudioSession sharedInstance] setActive:YES];
        [[SCAudioSession sharedInstance] addRouteChangeListener];
        
        // 音频打断处理
        [self addAudioSessionInterruptedObserver];
        
        // 初始化音频图
        [self createAudioUnitGraph];
    }
    return self;
}

- (void)dealloc {
    [self destroyAudioUnitGraph];
    DestroyBufferList(_mixbufferList);
    DestroyBufferList(_bgmBufferList);
}

#pragma mark - public method
- (void)startRecord {
    AudioStreamBasicDescription clientFormat;
    UInt32 fSize = sizeof (clientFormat);
    memset(&clientFormat, 0, sizeof(clientFormat));
    CheckStatus(AudioUnitGetProperty(_mixerUnit,
                         kAudioUnitProperty_StreamFormat,
                         kAudioUnitScope_Output,
                         outputElement,
                         &clientFormat,
                         &fSize),
                @"获取 mixer unit 输出端音频流格式失败",YES);
    _dataWriter = [[AUExtAudioFile alloc] initWithWritePath:_filePath
                                                       adsb:clientFormat
                                                 fileTypeId:AUAudioFileTypeCAF];
    
    OSStatus status = AUGraphStart(_auGraph);
    CheckStatus(status, @"启动音频图失败", YES);
}

- (void)stopRecord {
    OSStatus status = AUGraphStop(_auGraph);
    CheckStatus(status, @"停止音频图失败", YES);
    // 关闭文件和释放对象
    [_dataWriter closeFile];
}

#pragma mark - Audio Unit Graph
- (void)createAudioUnitGraph {
    // 1. 实例化音频单元图对象
    OSStatus status = NewAUGraph(&_auGraph);
    CheckStatus(status, @"实例化AUGraph对象失败", YES);
    // 2. 添加音频结点(AUGraphAddNode)
    [self addAudioUnitNodes];
    // 3. 打开音频单元图(激活Audio Unit Node)
    status = AUGraphOpen(_auGraph);
    CheckStatus(status, @"AUGraph对象打开失败", YES);
    // 4. 从结点中获取音频单元(AUGraphNodeInfo)
    [self getUnitsFromNodes];
    // 5. (*)设置音频单元属性
    [self setAudioUnitProperties];
    // 6. 连接音频单元
    [self makeNodeConnections];
    // 7. (*)展示音频单元图(空的...)
    CAShow(_auGraph);
    // 8. 初始化音频图(间接初始化 Audio Unit)
    status = AUGraphInitialize(_auGraph);
    CheckStatus(status, @"初始化AUGraph失败", YES);
}

- (void)addAudioUnitNodes {
    OSStatus status = noErr;
    AudioComponentDescription ioDescription;
    bzero(&ioDescription, sizeof(ioDescription));
    ioDescription.componentType = kAudioUnitType_Output;
    ioDescription.componentSubType = kAudioUnitSubType_RemoteIO;
    ioDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    status = AUGraphAddNode(_auGraph, &ioDescription, &_ioNode);
    CheckStatus(status, @"RemoteIO结点添加失败", YES);
    
    if (self.isEnableBgm) {
        AudioComponentDescription playerDescription;
        bzero(&playerDescription, sizeof(playerDescription));
        playerDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
        playerDescription.componentType = kAudioUnitType_Generator;
        playerDescription.componentSubType = kAudioUnitSubType_AudioFilePlayer;
        status = AUGraphAddNode(_auGraph, &playerDescription, &_playerNode);
        CheckStatus(status, @"Could not add Player node to AUGraph", YES);
        
        AudioComponentDescription mixerDescription;
        bzero(&mixerDescription, sizeof(mixerDescription));
        mixerDescription.componentType = kAudioUnitType_Mixer;
        mixerDescription.componentSubType = kAudioUnitSubType_MultiChannelMixer;
        mixerDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
        status = AUGraphAddNode(_auGraph, &mixerDescription, &_mixerNode);
        CheckStatus(status, @"Mixer结点添加失败", YES);
        
        AudioComponentDescription convertDescription;
        bzero(&convertDescription, sizeof(convertDescription));
        convertDescription.componentType = kAudioUnitType_FormatConverter;
        convertDescription.componentSubType = kAudioUnitSubType_AUConverter;
        convertDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
        status = AUGraphAddNode(_auGraph, &convertDescription, &_convertNode);
        CheckStatus(status, @"convert结点添加失败", YES);
    }
}

- (void)getUnitsFromNodes {
    OSStatus status = noErr;
    status = AUGraphNodeInfo(_auGraph, _ioNode, NULL, &_ioUnit);
    CheckStatus(status, @"获取RemoteIO单元失败", YES);
    if (self.isEnableBgm) {
        status = AUGraphNodeInfo(_auGraph, _playerNode, NULL, &_playerUnit);
        CheckStatus(status, @"获取player单元失败", YES);
        status = AUGraphNodeInfo(_auGraph, _mixerNode, NULL, &_mixerUnit);
        CheckStatus(status, @"获取Mixer单元失败", YES);
        status = AUGraphNodeInfo(_auGraph, _convertNode, NULL, &_convertUnit);
        CheckStatus(status, @"获取Convert单元失败", YES);
    }
}

- (void)setAudioUnitProperties {
    OSStatus status = noErr;
    
    // **************** 未压缩音频流格式（泛用） ****************
    AudioStreamBasicDescription micInputStreamFormat;
    micInputStreamFormat = [self getMicInputStreamFormat];
    
    // ------------------ 配置 Remote I/O Unit 属性 ------------------
    // 启用麦克风与输入元件的连接
    UInt32 enableInput = 1;
    status = AudioUnitSetProperty(_ioUnit,
                                  kAudioOutputUnitProperty_EnableIO,
                                  kAudioUnitScope_Input,
                                  inputElement,
                                  &enableInput,
                                  sizeof(enableInput));
    CheckStatus(status, @"RemoteIO 麦克风启用失败", YES);
    // 启用扬声器与输出元件的连接
    UInt32 enableOutput = 1;
    status = AudioUnitSetProperty(_ioUnit,
                                  kAudioOutputUnitProperty_EnableIO,
                                  kAudioUnitScope_Output,
                                  outputElement,
                                  &enableOutput,
                                  sizeof(enableOutput));
    CheckStatus(status, @"RemoteIO 扬声器启用失败", YES);
    // 设置切片最大帧数 - AudioUnitRender()函数在处理输入数据时，最大的输入吞吐量
    UInt32 maximumFramesPerSlice = 4096;
    status = AudioUnitSetProperty(_ioUnit,
                                  kAudioUnitProperty_MaximumFramesPerSlice,
                                  kAudioUnitScope_Global,
                                  outputElement,
                                  &maximumFramesPerSlice,
                                  sizeof (maximumFramesPerSlice));
    CheckStatus(status, @"RemoteIO 切片最大帧数设置失败", YES);
    // 输入元件输出端流格式
    CheckStatus(AudioUnitSetProperty(_ioUnit,
                                     kAudioUnitProperty_StreamFormat,
                                     kAudioUnitScope_Output,
                                     inputElement,
                                     &micInputStreamFormat,
                                     sizeof(micInputStreamFormat)),
                @"设置 RemoteIO 输入元件输出端流格式失败", YES);
    // 输出元件输入端流格式
//    if (self.isEnablePlayWhenRecord || self.enableBgm) {
        CheckStatus(AudioUnitSetProperty(_ioUnit,
                             kAudioUnitProperty_StreamFormat,
                             kAudioUnitScope_Input,
                             outputElement,
                             &micInputStreamFormat,
                             sizeof(micInputStreamFormat)),
                    @"设置 RemoteIO 输出元件输入端流格式失败", YES);
//    }
    // 输出元件输入端渲染回调
    AURenderCallbackStruct finalRenderProc;
    finalRenderProc.inputProc = &remoteIOInputDataCallback;
    finalRenderProc.inputProcRefCon = (__bridge void *)self;
    CheckStatus(AudioUnitSetProperty(_ioUnit,
                                     kAudioUnitProperty_SetRenderCallback,
                                     kAudioUnitScope_Input,
                                     outputElement,
                                     &finalRenderProc,
                                     sizeof(finalRenderProc)),
                @"设置 RemoteIO 输出元件输入端回调失败", YES);
    
    // ******************** 开启了背景音乐模式 ********************
    if (self.isEnableBgm) {
        // 播放器输出的流格式
        AudioStreamBasicDescription playerStreamFormat;
        playerStreamFormat = [self getPlayerStreamFormat];
        
        // ------------------ 配置 Player Unit 属性 ------------------
        // 输出端流格式
        status = AudioUnitSetProperty(_playerUnit,
                                      kAudioUnitProperty_StreamFormat,
                                      kAudioUnitScope_Output,
                                      0,
                                      &playerStreamFormat,
                                      sizeof(playerStreamFormat));
        CheckStatus(status, @"设置播放器元件输出端失败", YES);
        
        
        // ------------------ 配置 Convert Unit 属性 ------------------
        // playerStreamFormat ====================> micInputStreamFormat
        // 输入端流格式
        CheckStatus(AudioUnitSetProperty(_convertUnit,
                                         kAudioUnitProperty_StreamFormat,
                                         kAudioUnitScope_Input,
                                         0,
                                         &playerStreamFormat,
                                         sizeof(playerStreamFormat)),
                    @"设置转换器元件输入端流格式配置失败",YES);
        // 输出端流格式
        CheckStatus(AudioUnitSetProperty(_convertUnit,
                                         kAudioUnitProperty_StreamFormat,
                                         kAudioUnitScope_Output,
                                         0,
                                         &micInputStreamFormat,
                                         sizeof(micInputStreamFormat)),
                    @"设置转换器元件输出端流格式配置失败",YES);
        
        // ------------------ 配置 Mixer Unit 属性 ------------------
        // micInputStreamFormat
        //                      =================> micInputStreamFormat
        // micInputStreamFormat
        UInt32 mixerInputcount = 2;
        // 输入端元件数
        CheckStatus(AudioUnitSetProperty(_mixerUnit,
                                         kAudioUnitProperty_ElementCount,
                                         kAudioUnitScope_Input,
                                         0,
                                         &mixerInputcount,
                                         sizeof(mixerInputcount)),
                    @"配置混音器音轨数失败", YES);
        // 输出端采样率
        CheckStatus(AudioUnitSetProperty(_mixerUnit,
                                         kAudioUnitProperty_SampleRate,
                                         kAudioUnitScope_Output,
                                         0,
                                         &_sampleRate,
                                         sizeof(_sampleRate)),
                    @"配置混音器输出采样率失败", YES);
        // 循环配置元件
        for (int i = 0; i < mixerInputcount; ++i) {
            // 输入端流格式
            CheckStatus(AudioUnitSetProperty(_mixerUnit,
                                             kAudioUnitProperty_StreamFormat,
                                             kAudioUnitScope_Input,
                                             i,
                                             &micInputStreamFormat,
                                             sizeof(micInputStreamFormat)),
                        [NSString stringWithFormat:@"配置混音器%d号元件输入端流格式失败", i],
                        YES);
            AURenderCallbackStruct callback;
            // 输入端渲染回调
            callback.inputProc = mixerInputDataCallback;
            callback.inputProcRefCon = (__bridge void*)self;
            CheckStatus(AudioUnitSetProperty(_mixerUnit,
                                             kAudioUnitProperty_SetRenderCallback,
                                             kAudioUnitScope_Input,
                                             i,
                                             &callback,
                                             sizeof(callback)),
                        @"配置混音器输入端回调设置失败", YES);
        }
        // 输出端流格式
        CheckStatus(AudioUnitSetProperty(_mixerUnit,
                                      kAudioUnitProperty_StreamFormat,
                                      kAudioUnitScope_Output,
                                      0,
                                      &micInputStreamFormat,
                                      sizeof(micInputStreamFormat)),
                    @"配置混音器输出端流格式失败", YES);
        
        // ----------------- 音频单元参数设置 -----------------
        CheckStatus(AudioUnitSetParameter(_mixerUnit,
                                          kMultiChannelMixerParam_Volume,
                                          kAudioUnitScope_Input,
                                          0,
                                          1,
                                          0),
                    @"配置混音器音轨音量失败", YES);
        CheckStatus(AudioUnitSetParameter(_mixerUnit,
                                          kMultiChannelMixerParam_Volume,
                                          kAudioUnitScope_Input,
                                          1,
                                          1,
                                          0),
                    @"配置混音器音轨音量失败", YES);
    }
}

- (void)makeNodeConnections {
    OSStatus status = noErr;

    if (self.isEnableBgm) {
        status = AUGraphConnectNodeInput(_auGraph, _playerNode, 0, _convertNode, 0);
        
        // 不调用 AUGraphConnectNodeInput(_auGraph, _ioNode, 1, _mixerNode, 0); 的情况下，
        // 会导致 mixerUnit 并没有连接在音频图中，需要额外自己初始化才行
        // 结论：AUGraphInitialize 函数只换将“kAudioUnitType_Output”和“kAudioUnitType_Generator”连接的音频单元初始化
        //      对于单独未和“输出音频单元”有直接关系的音频单元会被直接跳过
        // 注意：需要在属性设置完毕后才得初始化
        status = AudioUnitInitialize(_mixerUnit);
        CheckStatus(status, @"初始化_mixerUnit失败", YES);
    }
}

- (void)destroyAudioUnitGraph {
    AUGraphStop(_auGraph);
    AUGraphUninitialize(_auGraph);
    AUGraphClose(_auGraph);
    AUGraphRemoveNode(_auGraph, _ioNode);
    AUGraphRemoveNode(_auGraph, _mixerNode);
    AUGraphRemoveNode(_auGraph, _convertNode);
    DisposeAUGraph(_auGraph);
    _ioNode = 0;
    _ioUnit = NULL;
    _mixerNode = 0;
    _mixerUnit = NULL;
    _convertNode = 0;
    _convertUnit = NULL;
    _auGraph = NULL;
}

#pragma mark - 核心回调函数
static OSStatus remoteIOInputDataCallback(void *inRefCon,
                                      AudioUnitRenderActionFlags *ioActionFlags,
                                      const AudioTimeStamp *inTimeStamp,
                                      UInt32 inBusNumber,
                                      UInt32 inNumberFrames,
                                      AudioBufferList *ioData) {
    OSStatus result = noErr;
    __unsafe_unretained AUAudioRecorder *recorder = (__bridge AUAudioRecorder *)inRefCon;
    
    // 渲染音频混合器结果
    AudioUnitRender(recorder->_mixerUnit,
                    ioActionFlags,
                    inTimeStamp,
                    0,
                    inNumberFrames,
                    recorder->_mixbufferList);
    
    // 将声音传到扬声器中
    if (recorder->_enablePlayWhenRecord) {
        CopyInterleavedBufferList(ioData, recorder->_mixbufferList);
    } else {
        if (recorder->_enableBgm) {
            CopyInterleavedBufferList(ioData, recorder->_bgmBufferList);
        }
    }
    
    // 异步向文件中写入数据
    result = [recorder->_dataWriter writeFrames:inNumberFrames
                                 toBufferData:recorder->_mixbufferList
                                        async:YES];
    
    return result;
}

static OSStatus mixerInputDataCallback(void *inRefCon,
                                       AudioUnitRenderActionFlags *ioActionFlags,
                                       const AudioTimeStamp *inTimeStamp,
                                       UInt32 inBusNumber,
                                       UInt32 inNumberFrames,
                                       AudioBufferList *ioData) {
    OSStatus result = noErr;
    __unsafe_unretained AUAudioRecorder *recorder = (__bridge AUAudioRecorder *)inRefCon;
    
    if (inBusNumber == 0) { // 还没有利用到，mixer Element 0 的回调未设置成功
        result = AudioUnitRender(recorder->_ioUnit, ioActionFlags, inTimeStamp, 1, inNumberFrames, ioData);
    } else if (inBusNumber == 1) {
        if (recorder->_enableBgm) {
            result = AudioUnitRender(recorder->_convertUnit, ioActionFlags, inTimeStamp, 0, inNumberFrames, ioData);
            CopyInterleavedBufferList(recorder->_bgmBufferList, ioData);
        }
    }

    return result;
}

#pragma mark - Setter
- (void)setVoiceVolume:(CGFloat)voiceVolume {
    _voiceVolume = voiceVolume;
    
    CheckStatus(AudioUnitSetParameter(_mixerUnit,
                          kMultiChannelMixerParam_Volume,
                          kAudioUnitScope_Input,
                          0,
                          voiceVolume,
                          0),
    @"配置混音器音轨音量失败", YES);
}

- (void)setBgmVolume:(CGFloat)bgmVolume {
    _bgmVolume = bgmVolume;
    
    CheckStatus(AudioUnitSetParameter(_mixerUnit,
                                      kMultiChannelMixerParam_Volume,
                                      kAudioUnitScope_Input,
                                      1,
                                      bgmVolume,
                                      0),
                @"配置混音器音轨音量失败", YES);
}

#pragma mark - AUAudioFilePlayer
- (void)playMusicWithPath:(NSString *)path {
    OSStatus status = noErr;
    
    // 创建可用URL
    NSURL *url = [NSURL URLWithString:path];
    CFURLRef songURL = (__bridge CFURLRef)url;
    
    // 打开的音频文件
    AudioFileID musicFile;
    status = AudioFileOpenURL(songURL, kAudioFileReadPermission, 0, &musicFile);
    CheckStatus(status, @"打开音频文件失败", YES);
    
    // 指定音频文件
    status = AudioUnitSetProperty(_playerUnit,
                                  kAudioUnitProperty_ScheduledFileIDs,
                                  kAudioUnitScope_Global,
                                  0,
                                  &musicFile,
                                  sizeof(musicFile));
    CheckStatus(status, @"指定音频文件失败", YES);
    
    // ----------------------- Getter --------------------------
    // 通过音频文件获取音频播放预计时长
    // kAudioFilePropertyEstimatedDuration
    Float64 estimatedDuration;
    UInt32 durationSize = sizeof(estimatedDuration);
    status = AudioFileGetProperty(musicFile,
                                  kAudioFilePropertyEstimatedDuration,
                                  &durationSize,
                                  &estimatedDuration);
    CheckStatus(status, @"获取音频数据流的格式失败", YES);
    NSLog(@"音频的预估时长为：%f", estimatedDuration);
    
    // 通过音频文件获取音频数据流的格式
    AudioStreamBasicDescription fileASBD;
    UInt32 propSize = sizeof(fileASBD);
    status = AudioFileGetProperty(musicFile,
                                  kAudioFilePropertyDataFormat,
                                  &propSize,
                                  &fileASBD);
    CheckStatus(status, @"获取音频数据流的格式失败", YES);
    // TODO: - 需要将这个ASBD接在AUGraph上
    
    // 通过音频文件获取音频数据包的数量
    UInt64 nPackets;
    UInt32 propsize = sizeof(nPackets);
    status = AudioFileGetProperty(musicFile,
                                  kAudioFilePropertyAudioDataPacketCount,
                                  &propsize,
                                  &nPackets);
    CheckStatus(status, @"获取音频数据包的数量失败", YES);
    // ---------------------------------------------------------
    
    // 告知文件播放单元从0开始播放整个文件
    ScheduledAudioFileRegion rgn;
    memset (&rgn.mTimeStamp, 0, sizeof(rgn.mTimeStamp));
    rgn.mTimeStamp.mFlags = kAudioTimeStampSampleTimeValid;
    rgn.mTimeStamp.mSampleTime = 0;
    // 该完成回调在unit读取磁盘信息完成后调用
    rgn.mCompletionProc = AudioFileRegionCompletionProc;//NULL;
    rgn.mCompletionProcUserData = (__bridge void*)self;//NULL;
    rgn.mAudioFile = musicFile;
    rgn.mLoopCount = 0;
    rgn.mStartFrame = 0;
    rgn.mFramesToPlay = (UInt32)nPackets * fileASBD.mFramesPerPacket; // -1
    status = AudioUnitSetProperty(_playerUnit,
                                  kAudioUnitProperty_ScheduledFileRegion,
                                  kAudioUnitScope_Global,
                                  0,
                                  &rgn,
                                  sizeof(rgn));
    CheckStatus(status, @"设置播放位置失败", YES);
    
    // 设置文件播放单元参数为默认值
    // ScheduledFilePrime 用于设置磁盘读取样本帧数
    UInt32 defaultVal = 0;
    status = AudioUnitSetProperty(_playerUnit,
                                  kAudioUnitProperty_ScheduledFilePrime,
                                  kAudioUnitScope_Global,
                                  0,
                                  &defaultVal,
                                  sizeof(defaultVal));
    CheckStatus(status, @"ScheduledFilePrime 设置失败", YES);
    
    // 设置何时开始播放(播放模式)
    AudioTimeStamp startTime;
    memset (&startTime, 0, sizeof(startTime));
    startTime.mFlags = kAudioTimeStampSampleTimeValid;
    startTime.mSampleTime = -1; // 下一个渲染循环
    status = AudioUnitSetProperty(_playerUnit,
                                  kAudioUnitProperty_ScheduleStartTimeStamp,
                                  kAudioUnitScope_Global,
                                  0,
                                  &startTime,
                                  sizeof(startTime));
    CheckStatus(status, @"设置启动时间失败", YES);
    
    // 通过计时器获取回调 kAudioUnitProperty_CurrentPlayTime 获取进度
}

void AudioFileRegionCompletionProc(void * __nullable userData,
                                   ScheduledAudioFileRegion *fileRegion,
                                   OSStatus result) {
    if (result == noErr) {
        __unsafe_unretained AUAudioRecorder *recorder = (__bridge AUAudioRecorder *)userData;
        [recorder debugScheduledAudioFileRegion:*fileRegion];
        AudioTimeStamp curTime;
        UInt32 curTimeSize = sizeof(curTime);
        result = AudioUnitGetProperty(recorder->_playerUnit,
                                      kAudioUnitProperty_CurrentPlayTime,
                                      kAudioUnitScope_Global,
                                      0,
                                      &curTime,
                                      &curTimeSize);
        CheckStatus(result, @"获取音频数据流的格式失败", YES);
        [recorder debugAudioTimeStamp:curTime];
    } else {
        NSLog(@"Error: %d", result);
    }
}

- (void)endPlayMusic {
    OSStatus status = noErr;
    status = AudioUnitReset(_playerUnit, kAudioUnitScope_Global, 0);
    CheckStatus(status, @"重置音频单元失败", YES);
}

#pragma mark - help
- (void)debugAudioTimeStamp:(AudioTimeStamp)ats {
    NSLog(@"--------AudioTimeStamp-------");
    NSLog(@"mSampleTime:    %f", ats.mSampleTime);
    NSLog(@"mSampleTime(s): %f", ats.mSampleTime / 100000);
    NSLog(@"mHostTime:      %llu", ats.mHostTime);
    NSLog(@"mRateScalar:    %f", ats.mRateScalar);
    NSLog(@"mWordClockTime: %llu", ats.mWordClockTime);
    // TODO: SMPTETime 显示时间
    NSLog(@"mFlags:         %d", ats.mFlags);
    NSLog(@"mReserved:      %u", (unsigned int)ats.mReserved);
    NSLog(@"-----------------------------");
}

- (void)debugScheduledAudioFileRegion:(ScheduledAudioFileRegion)rgn {
    NSLog(@"---ScheduledAudioFileRegion---");
    [self debugAudioTimeStamp:rgn.mTimeStamp];
    NSLog(@"mStartFrame:    %lld", rgn.mStartFrame);
    NSLog(@"mFramesToPlay:  %d", rgn.mFramesToPlay);
    NSLog(@"-----------------------------");
}

- (AudioStreamBasicDescription)getPlayerStreamFormat {
    AudioStreamBasicDescription playerStreamFormat; // 立体声流格式
    UInt32 bytesPerSample = sizeof(Float32);
    bzero(&playerStreamFormat, sizeof(playerStreamFormat));
    playerStreamFormat.mFormatID          = kAudioFormatLinearPCM;
    playerStreamFormat.mFormatFlags       = kAudioFormatFlagsNativeFloatPacked | kAudioFormatFlagIsNonInterleaved;
    playerStreamFormat.mBytesPerPacket    = bytesPerSample;
    playerStreamFormat.mFramesPerPacket   = 1;
    playerStreamFormat.mBytesPerFrame     = bytesPerSample;
    playerStreamFormat.mChannelsPerFrame  = 2;
    playerStreamFormat.mBitsPerChannel    = 8 * bytesPerSample;
    playerStreamFormat.mSampleRate        = 41000; // 48000.0;
    return playerStreamFormat;
}

- (AudioStreamBasicDescription)getMicInputStreamFormat {
    AudioStreamBasicDescription micInputStreamFormat;
    AudioFormatFlags formatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked;
    micInputStreamFormat = linearPCMStreamDes(formatFlags,
                                              _sampleRate,
                                              2,
                                              sizeof(UInt16));
    return micInputStreamFormat;
}

@end
