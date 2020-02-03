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

static const AudioUnitElement inputElement = 1;
static const AudioUnitElement outputElement = 0;

/** AUGraph 音频流流程（以此为准）
 * 🎙 -> RemoteIO(InputElement) -[stereoStreamFormat]->
 * AudioConverter -[clientFormat32float]-> MixerUnit(Bus0)
 * -[clientFormat32float]-> RemoteIO(OutputElement) -> 🔈
 */

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

@property (nonatomic, assign, getter=isEnablePlayWhenRecord) BOOL enablePlayWhenRecord;
@property (nonatomic, assign, getter=isEnableMixer) BOOL enableMixer;

@end

#define BufferList_cache_size (1024*10*5)
@implementation AUAudioRecorder
{
    AudioBufferList* _bufferList;
    AUExtAudioFile*  _dataWriter;

    NSString*        _backgroundPath;
    AUExtAudioFile*  _dataReader;
    AudioStreamBasicDescription _mixerStreamDesForInput;    // 混音器的输入数据格式
    AudioBufferList* _mixerBufferList;
}
#pragma mark - life cycle
- (instancetype)initWithPath:(NSString*)path {
    if (self = [self init]) {
        // 属性初始化
        _filePath = path;
        _sampleRate = 44100.0;
        _channels = 2;
        
        self.enablePlayWhenRecord = NO;
        
        _bufferList = CreateBufferList(2, NO, BufferList_cache_size);
        
        // --------------------------------------------------------------
        _mixerBufferList = CreateBufferList(2, NO, BufferList_cache_size);
        self.enableMixer = YES;
        _backgroundPath = [NSString bundlePath:@"background.mp3"];
        UInt32 bytesPerSample = 4;  // 要与下面mFormatFlags 对应
        AudioStreamBasicDescription absd;
        absd.mFormatID          = kAudioFormatLinearPCM;
        absd.mFormatFlags       = kAudioFormatFlagsNativeFloatPacked;
        absd.mBytesPerPacket    = bytesPerSample;
        absd.mFramesPerPacket   = 1;
        absd.mBytesPerFrame     = 4;
        absd.mChannelsPerFrame  = 2;
        absd.mBitsPerChannel    = 8 * bytesPerSample;
        absd.mSampleRate        = 0;
        
        _dataReader = [[AUExtAudioFile alloc] initWithReadPath:path adsb:absd canrepeat:NO];
        _mixerStreamDesForInput = _dataReader.clientABSD;
        // --------------------------------------------------------------
        
        // 音频会话设置
        [[SCAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord];
        [[SCAudioSession sharedInstance] setPreferredSampleRate:_sampleRate];
        [[SCAudioSession sharedInstance] setActive:YES];
        [[SCAudioSession sharedInstance] addRouteChangeListener];
        
        // 音频打断处理
        [self addAudioSessionInterruptedObserver];
        
        // 初始化音频图
        [self createAudioUnitGraph];
        
        [self setUpFilePlayer];
        
        [self checkFormat];
    }
    return self;
}

- (void)dealloc {
    [self destroyAudioUnitGraph];
    DestroyBufferList(_bufferList);
}

#pragma mark - public method
- (void)start {
    AudioStreamBasicDescription clientFormat;
    UInt32 fSize = sizeof (clientFormat);
    memset(&clientFormat, 0, sizeof(clientFormat));
//    CheckStatus(AudioUnitGetProperty(_ioUnit,
//                                     kAudioUnitProperty_StreamFormat,
//                                     kAudioUnitScope_Output,
//                                     inputElement,
//                                     &clientFormat,
//                                     &fSize),
//                @"AudioUnitGetProperty on failed",
//                YES);
    CheckStatus(AudioUnitGetProperty(_mixerUnit,
                         kAudioUnitProperty_StreamFormat,
                         kAudioUnitScope_Output,
                         outputElement,
                         &clientFormat,
                         &fSize),
    @"AudioUnitGetProperty on failed",
    YES);
    NSLog(@"---------------------- clientFormat --------------------------");
    /*
     2020-02-03 23:25:52.783710+0800 AVDemo[57007:1653650] ---------------------- clientFormat --------------------------
     Sample Rate:              44100
     Format ID:                 lpcm
     Format Flags:                 C
     Bytes per Packet:             4
     Frames per Packet:            1
     Bytes per Frame:              4
     Channels per Frame:           2
     Bits per Channel:            16
     Reserved:                     0
     */
    
    printAudioStreamFormat(clientFormat);
    _dataWriter = [[AUExtAudioFile alloc] initWithWritePath:_filePath adsb:clientFormat fileTypeId:AUAudioFileTypeCAF];
//    _dataWriter = [[AUExtAudioFile alloc] initWithWritePath:_filePath adsb:clientFormat fileTypeId:AUAudioFileTypeM4A];
    
    OSStatus status = AUGraphStart(_auGraph);
    CheckStatus(status, @"启动音频图失败", YES);
}

- (void)stop {
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
    // 7. 设置数据源方法
    [self setupRenderCallback];
    // 7. (*)展示音频单元图(空的...)
    CAShow(_auGraph);
    // 8. 初始化音频图
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
    
    if (self.isEnableMixer) {
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
    if (self.isEnableMixer) {
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
    // 激活 RemoteIO 的 IO 功能
    UInt32 enableIO = 1;
    status = AudioUnitSetProperty(_ioUnit,
                                  kAudioOutputUnitProperty_EnableIO,
                                  kAudioUnitScope_Input,
                                  inputElement,
                                  &enableIO,
                                  sizeof(enableIO));
    CheckStatus(status, @"麦克风 启动失败", YES);
    status = AudioUnitSetProperty(_ioUnit,
                                  kAudioOutputUnitProperty_EnableIO,
                                  kAudioUnitScope_Output,
                                  outputElement,
                                  &enableIO,
                                  sizeof(enableIO));
    CheckStatus(status, @"扬声器 启动失败", YES);
    // 设置 RemoteIO 切片最大帧数（输出端全局域）
    // AudioUnitRender()函数在处理输入数据时，最大的输入吞吐量
    UInt32 maximumFramesPerSlice = 4096;
    status = AudioUnitSetProperty(_ioUnit,
                                  kAudioUnitProperty_MaximumFramesPerSlice,
                                  kAudioUnitScope_Global,
                                  outputElement,
                                  &maximumFramesPerSlice,
                                  sizeof (maximumFramesPerSlice));
    CheckStatus(status, @"RemoteIO 切片最大帧数设置失败", YES);
    
    // 设置音频图中的音频流格式
    AudioStreamBasicDescription micInputStreamFormat;
    AudioFormatFlags formatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    micInputStreamFormat = linearPCMStreamDes(formatFlags,
                                         _sampleRate,
                                         2,
                                         sizeof(UInt16));
    NSLog(@"---------------------- micInputStreamFormat --------------------------");
    printAudioStreamFormat(micInputStreamFormat);
    
    // RemoteIO 流格式
    AudioUnitSetProperty(_ioUnit,
                         kAudioUnitProperty_StreamFormat,
                         kAudioUnitScope_Output,
                         inputElement,
                         &micInputStreamFormat,
                         sizeof(micInputStreamFormat));
//    if (self.isEnablePlayWhenRecord) {
        AudioUnitSetProperty(_ioUnit,
                             kAudioUnitProperty_StreamFormat,
                             kAudioUnitScope_Input,
                             outputElement,
                             &micInputStreamFormat,
                             sizeof(micInputStreamFormat));
//    }
    
    if (self.isEnableMixer) {
        // player
        AudioStreamBasicDescription playerStreamFormat; // 立体声流格式
        UInt32 bytesPerSample = sizeof(Float32);
        bzero(&playerStreamFormat, sizeof(playerStreamFormat));
        playerStreamFormat.mFormatID          = kAudioFormatLinearPCM;
        playerStreamFormat.mFormatFlags       = kAudioFormatFlagsNativeFloatPacked | kAudioFormatFlagIsNonInterleaved;
        playerStreamFormat.mBytesPerPacket    = bytesPerSample;
        playerStreamFormat.mFramesPerPacket   = 1;
        playerStreamFormat.mBytesPerFrame     = bytesPerSample;
        playerStreamFormat.mChannelsPerFrame  = 2;                    // 2 indicates stereo
        playerStreamFormat.mBitsPerChannel    = 8 * bytesPerSample;
        playerStreamFormat.mSampleRate        = 41000;//48000.0;
        status = AudioUnitSetProperty(_playerUnit,
                                      kAudioUnitProperty_StreamFormat,
                                      kAudioUnitScope_Output,
                                      0,
                                      &playerStreamFormat,
                                      sizeof(playerStreamFormat));
        CheckStatus(status, @"playerStreamFormat error", YES);
        
        // convert
        CheckStatus(AudioUnitSetProperty(_convertUnit,
                             kAudioUnitProperty_StreamFormat,
                             kAudioUnitScope_Input,
                             0,
                             &playerStreamFormat,
                             sizeof(playerStreamFormat)),
        @"转换器器输入流格式配置失败",YES);
        CheckStatus(AudioUnitSetProperty(_convertUnit,
                             kAudioUnitProperty_StreamFormat,
                             kAudioUnitScope_Output,
                             0,
                             &micInputStreamFormat,
                             sizeof(micInputStreamFormat)),
        @"转换器器输出流格式配置失败",YES);
        
        // mixer
        UInt32 mixerInputcount = 2;
        CheckStatus(AudioUnitSetProperty(_mixerUnit,
                                         kAudioUnitProperty_ElementCount,
                                         kAudioUnitScope_Input,
                                         0,
                                         &mixerInputcount,
                                         sizeof(mixerInputcount)),
                    @"配置混音器音轨数失败", YES);
        
        CheckStatus(AudioUnitSetProperty(_mixerUnit,
                                         kAudioUnitProperty_SampleRate,
                                         kAudioUnitScope_Output,
                                         0,
                                         &_sampleRate,
                                         sizeof(_sampleRate)),
                    @"配置混音器输出采样率失败", YES);
        
        for (int i=0; i < mixerInputcount; ++i) {
            status = AudioUnitSetProperty(_mixerUnit,
                                          kAudioUnitProperty_StreamFormat,
                                          kAudioUnitScope_Input,
                                          i,
                                          &micInputStreamFormat,
                                          sizeof(micInputStreamFormat));
            if (status != noErr) {
                NSLog(@"AudioUnitSetProperty kAudioUnitProperty_StreamFormat %d",status);
            }
            
//            AURenderCallbackStruct callback;
//            callback.inputProc = mixerInputDataCallback;
//            callback.inputProcRefCon = (__bridge void*)self;
//            status = AudioUnitSetProperty(_mixerUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, i, &callback, sizeof(callback));
//            if (status != noErr) {
//                NSLog(@"AudioUnitSetProperty kAudioUnitProperty_SetRenderCallback %d",status);
//            }
        }
        
        status = AudioUnitSetProperty(_mixerUnit,
                                      kAudioUnitProperty_StreamFormat,
                                      kAudioUnitScope_Output,
                                      0,
                                      &micInputStreamFormat,
                                      sizeof(micInputStreamFormat));
        if (status != noErr) {
            NSLog(@"AudioUnitSetProperty kAudioUnitProperty_StreamFormat %d",status);
        }
    
        CheckStatus(AudioUnitSetParameter(_mixerUnit,
                                          kMultiChannelMixerParam_Volume,
                                          kAudioUnitScope_Input,
                                          0,
                                          1,
                                          0),
                    @"Input Volume Error", YES);
        CheckStatus(AudioUnitSetParameter(_mixerUnit,
                                          kMultiChannelMixerParam_Volume,
                                          kAudioUnitScope_Input,
                                          1,
                                          0.5,
                                          0),
                    @"Input Volume Error", YES);
        
//        AudioStreamBasicDescription mixerStreamFormat;
//        AudioFormatFlags mixerFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
//        mixerStreamFormat = linearPCMStreamDes(mixerFlags,
//                                               _sampleRate,
//                                               _channels,
//                                               sizeof(UInt16));
    }
}

- (void)makeNodeConnections {
    OSStatus status = noErr;
    if (self.isEnablePlayWhenRecord) {
        status = AUGraphConnectNodeInput(_auGraph,
                                         _ioNode, inputElement,
                                         _ioNode, outputElement);
    }
    
    if (self.isEnableMixer) {
        
        status = AUGraphConnectNodeInput(_auGraph, _ioNode, 1, _mixerNode, 0);
        
        status = AUGraphConnectNodeInput(_auGraph, _playerNode, 0, _convertNode, 0);
        status = AUGraphConnectNodeInput(_auGraph, _convertNode, 0, _mixerNode, 1);
        
//        status = AUGraphConnectNodeInput(_auGraph, _mixerNode, 0, _ioNode, 0);
    }
    
//    AURenderCallbackStruct finalRenderProc;
//    finalRenderProc.inputProc = &saveOutputCallback;
//    finalRenderProc.inputProcRefCon = (__bridge void *)self;
//    // AUGraphSetNodeInputCallback
//    status = AudioUnitSetProperty(_ioUnit,
//                                  kAudioOutputUnitProperty_SetInputCallback,
//                                  kAudioUnitScope_Output,
//                                  1,
//                                  &finalRenderProc,
//                                  sizeof(finalRenderProc));
//    CheckStatus(status, @"设置 RemoteIO 输出回调失败", YES);
    
    AURenderCallbackStruct finalRenderProc;
    finalRenderProc.inputProc = &saveMixerOutputCallback;
    finalRenderProc.inputProcRefCon = (__bridge void *)self;
    status = AUGraphSetNodeInputCallback(_auGraph,
                                         _ioNode,
                                         outputElement,
                                         &finalRenderProc);
    CheckStatus(status, @"设置 RemoteIO 输出回调失败", YES);
}

- (void)setupRenderCallback {
//    OSStatus status;
//    AURenderCallbackStruct finalRenderProc;
//    finalRenderProc.inputProc = &saveOutputCallback;
//    finalRenderProc.inputProcRefCon = (__bridge void *)self;
//    status = AudioUnitSetProperty(_ioUnit,
//                                  kAudioOutputUnitProperty_SetInputCallback,
//                                  kAudioUnitScope_Output,
//                                  inputElement,
//                                  &finalRenderProc,
//                                  sizeof(finalRenderProc));
//    CheckStatus(status, @"设置 RemoteIO 输出回调失败", YES);
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
static OSStatus saveMixerOutputCallback(void *inRefCon,
                               AudioUnitRenderActionFlags *ioActionFlags,
                               const AudioTimeStamp *inTimeStamp,
                               UInt32 inBusNumber,
                               UInt32 inNumberFrames,
                               AudioBufferList *ioData) {
    OSStatus result = noErr;
    __unsafe_unretained AUAudioRecorder *recorder = (__bridge AUAudioRecorder *)inRefCon;
    
//    AudioUnitRender(recorder->_convertUnit, ioActionFlags, inTimeStamp, 0, inNumberFrames, ioData);
    
    AudioUnitRender(recorder->_mixerUnit,
                    ioActionFlags,
                    inTimeStamp,
                    0, // 1
                    inNumberFrames,
                    recorder->_bufferList);

    // 异步向文件中写入数据
    result = [recorder->_dataWriter writeFrames:inNumberFrames
                                 toBufferData:recorder->_bufferList
                                        async:YES];
    
    return result;
}

static OSStatus saveOutputCallback(void *inRefCon,
                               AudioUnitRenderActionFlags *ioActionFlags,
                               const AudioTimeStamp *inTimeStamp,
                               UInt32 inBusNumber,
                               UInt32 inNumberFrames,
                               AudioBufferList *ioData) {
    OSStatus result = noErr;
    __unsafe_unretained AUAudioRecorder *recorder = (__bridge AUAudioRecorder *)inRefCon;
    
    AudioUnitRender(recorder->_ioUnit,
                    ioActionFlags,
                    inTimeStamp,
                    inBusNumber, // 1
                    inNumberFrames,
                    recorder->_bufferList);

    // 异步向文件中写入数据
    result = [recorder->_dataWriter writeFrames:inNumberFrames
                                 toBufferData:recorder->_bufferList
                                        async:YES];
    
    return result;
}

//static OSStatus mixerInputDataCallback(void *inRefCon,
//                                       AudioUnitRenderActionFlags *ioActionFlags,
//                                       const AudioTimeStamp *inTimeStamp,
//                                       UInt32 inBusNumber,
//                                       UInt32 inNumberFrames,
//                                       AudioBufferList *ioData) {
//    OSStatus result = noErr;
//    __unsafe_unretained AUAudioRecorder *recorder = (__bridge AUAudioRecorder *)inRefCon;
//
//    if (inBusNumber == 0) {     // 代表录音
//        // 将录音的数据填充进来
//        result = AudioUnitRender(recorder->_ioUnit, ioActionFlags, inTimeStamp, 1, inNumberFrames, ioData);
//    } else if (inBusNumber == 1){   // 代表音频文件
//        // 从音频文件中读取数据并填充进来
////        result = [recorder->_dataReader readFrames:&inNumberFrames toBufferData:ioData];
//        result = AudioUnitRender(recorder->_convertUnit, ioActionFlags, inTimeStamp, 0, inNumberFrames, ioData);
//    }
//
//    return result;
//}

- (void)setUpFilePlayer {
    OSStatus status = noErr;
    AudioFileID musicFile;
    NSURL *url = [NSURL URLWithString:_backgroundPath];
    CFURLRef songURL = (__bridge  CFURLRef)url;
    // 打开输入的音频文件
    status = AudioFileOpenURL(songURL, kAudioFileReadPermission, 0, &musicFile);
    CheckStatus(status, @"Open AudioFile... ", YES);
    
    // 在全局域的输出元素中设置播放器单元目标文件
    status = AudioUnitSetProperty(_playerUnit,
                                  kAudioUnitProperty_ScheduledFileIDs,
                                  kAudioUnitScope_Global,
                                  0,
                                  &musicFile,
                                  sizeof(musicFile));
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
    status = AudioUnitSetProperty(_playerUnit,
                                  kAudioUnitProperty_ScheduledFileRegion,
                                  kAudioUnitScope_Global,
                                  0,
                                  &rgn,
                                  sizeof(rgn));
    CheckStatus(status, @"Set Region... ", YES);
    
    // 设置文件播放单元参数为默认值
    UInt32 defaultVal = 0;
    status = AudioUnitSetProperty(_playerUnit,
                                  kAudioUnitProperty_ScheduledFilePrime,
                                  kAudioUnitScope_Global,
                                  0,
                                  &defaultVal,
                                  sizeof(defaultVal));
    CheckStatus(status, @"Prime Player Unit With Default Value... ", YES);
    
    // 设置何时开始播放(播放模式)(-1 sample time means next render cycle)
    AudioTimeStamp startTime;
    memset (&startTime, 0, sizeof(startTime));
    startTime.mFlags = kAudioTimeStampSampleTimeValid;
    startTime.mSampleTime = -1;
    status = AudioUnitSetProperty(_playerUnit,
                                  kAudioUnitProperty_ScheduleStartTimeStamp,
                                  kAudioUnitScope_Global,
                                  0,
                                  &startTime,
                                  sizeof(startTime));
    CheckStatus(status, @"set Player Unit Start Time... ", YES);
}

#pragma mark - Check
- (void)checkFormat {
    AudioStreamBasicDescription clientFormat;
    UInt32 fSize = sizeof(clientFormat);
    memset(&clientFormat, 0, sizeof(clientFormat));
    CheckStatus(AudioUnitGetProperty(_convertUnit,
                                     kAudioUnitProperty_StreamFormat,
                                     kAudioUnitScope_Input,
                                     0,
                                     &clientFormat,
                                     &fSize),
                @"AudioUnitGetProperty on failed",
                YES);
    NSLog(@"============== convert input ==============");
    printAudioStreamFormat(clientFormat);
    
    memset(&clientFormat, 0, sizeof(clientFormat));
    CheckStatus(AudioUnitGetProperty(_convertUnit,
                                     kAudioUnitProperty_StreamFormat,
                                     kAudioUnitScope_Output,
                                     0,
                                     &clientFormat,
                                     &fSize),
                @"AudioUnitGetProperty on failed",
                YES);
    NSLog(@"============== convert output ==============");
    printAudioStreamFormat(clientFormat);
    
    memset(&clientFormat, 0, sizeof(clientFormat));
    CheckStatus(AudioUnitGetProperty(_ioUnit,
                                     kAudioUnitProperty_StreamFormat,
                                     kAudioUnitScope_Output,
                                     1,
                                     &clientFormat,
                                     &fSize),
                @"AudioUnitGetProperty on failed",
                YES);
    NSLog(@"============== io 1 output ==============");
    printAudioStreamFormat(clientFormat);
    
    memset(&clientFormat, 0, sizeof(clientFormat));
    CheckStatus(AudioUnitGetProperty(_ioUnit,
                                     kAudioUnitProperty_StreamFormat,
                                     kAudioUnitScope_Input,
                                     0,
                                     &clientFormat,
                                     &fSize),
                @"AudioUnitGetProperty on failed",
                YES);
    NSLog(@"============== io 0 input ==============");
    printAudioStreamFormat(clientFormat);
    
    memset(&clientFormat, 0, sizeof(clientFormat));
    CheckStatus(AudioUnitGetProperty(_mixerUnit,
                                     kAudioUnitProperty_StreamFormat,
                                     kAudioUnitScope_Output,
                                     0,
                                     &clientFormat,
                                     &fSize),
                @"AudioUnitGetProperty on failed",
                YES);
    NSLog(@"============== mixer output ==============");
    printAudioStreamFormat(clientFormat);
    
    CAShow(_auGraph);
}

@end
