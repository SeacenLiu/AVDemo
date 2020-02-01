//
//  AUAudioOutput.m
//  AVDemo
//
//  Created by SeacenLiu on 2020/1/31.
//  Copyright © 2020 SeacenLiu. All rights reserved.
//

/**
 * * 音频会话配置
 * 1: 创建自定义会话
 * 2: 设置监听者
 *       打断处理
 *       音频路线改变处理
 *       (*)TODO: - 硬件音量变化处理
 * 3: 设置输入输出缓冲时长
 * 4: 激活音频会话
 *
 * * 音频单元配置
 * 1:通过AudioComponentDescription创建AudioUnit实例
 * 2:通过AudioStreamBasicDescription配置AudioUnit属性
 * 3:连接AudioUnit中的结点或设置RenderCallback
 * 4:初始化AudioUnit
 * 5:启动AudioOutput
 *
 **/

#import "AUAudioOutput.h"
#import <AudioToolbox/AudioToolbox.h>
#import <Accelerate/Accelerate.h>
#import "SCAudioSession.h"
#import "NSString+Path.h"
#import "AUAudioOutput+Interruption.h"

// 音频单元元素0
static const AudioUnitElement element0 = 0;

const float SMAudioIOBufferDurationSmall = 0.0058f;

// 输入回调函数声明
static OSStatus InputRenderCallback(void *inRefCon,
                                    AudioUnitRenderActionFlags *ioActionFlags,
                                    const AudioTimeStamp *inTimeStamp,
                                    UInt32 inBusNumber,
                                    UInt32 inNumberFrames,
                                    AudioBufferList *ioData);

@interface AUAudioOutput () {
    SInt16*  _outData; // 输出数据
}

// 音频图结构
@property(nonatomic, assign) AUGraph            auGraph;
// 输入输出部分
@property(nonatomic, assign) AUNode             ioNode;
@property(nonatomic, assign) AudioUnit          ioUnit;
// 音频转换部分
@property(nonatomic, assign) AUNode             convertNode;
@property(nonatomic, assign) AudioUnit          convertUnit;

// 填充音频数据代理
@property (readwrite, copy) id<AUAudioOutputFillDataDelegate> fillAudioDataDelegate;

@end

@implementation AUAudioOutput

#pragma mark - life cycle
- (instancetype)initWithChannels:(NSInteger)channels
                      sampleRate:(NSInteger)sampleRate
                  bytesPerSample:(NSInteger)bytePerSample
               filleDataDelegate:(id<AUAudioOutputFillDataDelegate>)fillAudioDataDelegate {
    if (self = [super init]) {
        // 音频会话配置
        [[SCAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback];
        [[SCAudioSession sharedInstance] setPreferredSampleRate:sampleRate];
        [[SCAudioSession sharedInstance] setActive:YES];
        [[SCAudioSession sharedInstance] setPreferredLatency:SMAudioIOBufferDurationSmall * 4];
        [[SCAudioSession sharedInstance] addRouteChangeListener];
        
        // 添加打断处理
        [self addAudioSessionInterruptedObserver];
        
        // 初始化变量
        _outData = (SInt16 *)calloc(8192, sizeof(SInt16));
        _fillAudioDataDelegate = fillAudioDataDelegate;
        _sampleRate = sampleRate;
        _channels = channels;
        
        // 创建音频图
        [self createAudioUnitGraph];
    }
    return self;
}

- (void)dealloc {
    if (_outData) {
        free(_outData);
        _outData = NULL;
    }
    
    [self destroyAudioUnitGraph];
    [self removeAudioSessionInterruptedObserver];
}

#pragma mark - Public Method
- (BOOL)play {
    OSStatus status = AUGraphStart(_auGraph);
    CheckStatus(status, @"Could not start AUGraph", YES);
    return YES;
}

- (BOOL)stop {
    OSStatus status = AUGraphStop(_auGraph);
    CheckStatus(status, @"Could not stop AUGraph", YES);
    return YES;
}

#pragma mark - Private Method
- (void)createAudioUnitGraph {
    OSStatus status = noErr;
    // 1. 创建音频图
    status = NewAUGraph(&_auGraph);
    CheckStatus(status, @"Could not create a new AUGraph", YES);
    // 2. 添加音频结点（结点属于音频图的数据结构）
    [self addAudioUnitNodes];
    // 3. 打开音频图(激活所有子节点)
    status = AUGraphOpen(_auGraph);
    CheckStatus(status, @"Could not open AUGraph", YES);
    // 4. 从音频结点中获取音频单元
    [self getUnitsFromNodes];
    // 5. 配置音频单元属性
    [self setAudioUnitProperties];
    // 6. 连接音频结点
    [self makeNodeConnections];
    // 7. 打印当前音频图
    CAShow(_auGraph);
    // 8. 实例化音频图
    status = AUGraphInitialize(_auGraph);
    CheckStatus(status, @"Could not initialize AUGraph", YES);
}

- (void)addAudioUnitNodes {
    OSStatus status = noErr;
    // 1. 配置I/O结点
    // 1-1: 定义I/O结点描述
    AudioComponentDescription ioDescription;
    bzero(&ioDescription, sizeof(ioDescription));
    ioDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    ioDescription.componentType = kAudioUnitType_Output;
    ioDescription.componentSubType = kAudioUnitSubType_RemoteIO;
    // 1-2: 添加I/O结点
    status = AUGraphAddNode(_auGraph, &ioDescription, &_ioNode);
    CheckStatus(status, @"Could not add I/O node to AUGraph", YES);
    // 2. 配置转换器结点
    // 2-1: 定义转换器描述
    AudioComponentDescription convertDescription;
    bzero(&convertDescription, sizeof(convertDescription));
    convertDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    convertDescription.componentType = kAudioUnitType_FormatConverter;
    convertDescription.componentSubType = kAudioUnitSubType_AUConverter;
    // 2-2: 添加转换器结点
    status = AUGraphAddNode(_auGraph, &convertDescription, &_convertNode);
    CheckStatus(status, @"Could not add Convert node to AUGraph", YES);
}

- (void)getUnitsFromNodes {
    OSStatus status = noErr;
    // 实例化I/O单元
    status = AUGraphNodeInfo(_auGraph, _ioNode, NULL, &_ioUnit);
    CheckStatus(status, @"Could not retrieve node info for I/O node", YES);
    // 实例化转换器单元
    status = AUGraphNodeInfo(_auGraph, _convertNode, NULL, &_convertUnit);
    CheckStatus(status, @"Could not retrieve node info for Convert node", YES);
}

- (void)setAudioUnitProperties {
    OSStatus status = noErr;
    // 1. 设置I/O单元属性
    // 1-1: 开启IO功能
    UInt32 flag = 1;
    status = AudioUnitSetProperty(_ioUnit,
                                  kAudioOutputUnitProperty_EnableIO,
                                  kAudioUnitScope_Output,
                                  element0,
                                  &flag,
                                  sizeof(flag));
    CheckStatus(status, @"I/O unit enableio error", YES);
    // 1-2: 定义音频流格式
    AudioStreamBasicDescription float32StreamFormat;
    UInt32 bytesPerSample = sizeof(Float32); // 8
    bzero(&float32StreamFormat, sizeof(float32StreamFormat));
    float32StreamFormat.mSampleRate             = _sampleRate;
    float32StreamFormat.mFormatID               = kAudioFormatLinearPCM;
    float32StreamFormat.mFormatFlags            = kAudioFormatFlagsNativeFloatPacked | kAudioFormatFlagIsNonInterleaved;
    float32StreamFormat.mBytesPerPacket         = bytesPerSample;
    float32StreamFormat.mFramesPerPacket        = 1;
    float32StreamFormat.mBytesPerFrame          = bytesPerSample;
    float32StreamFormat.mChannelsPerFrame       = _channels;
    float32StreamFormat.mBitsPerChannel         = 8 * bytesPerSample;
    // 1-3: 设置I/O单元在输入流格式
    status = AudioUnitSetProperty(_ioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  element0,
                                  &float32StreamFormat,
                                  sizeof(float32StreamFormat));
    
    // 2. 设置转换器单元属性
    // 2-1: 定义客户端流格式
    AudioStreamBasicDescription sint16StreamFormat;
    bytesPerSample = sizeof(SInt16); // 2
    bzero(&sint16StreamFormat, sizeof(sint16StreamFormat));
    sint16StreamFormat.mSampleRate        = _sampleRate;
    sint16StreamFormat.mFormatID          = kAudioFormatLinearPCM;
    sint16StreamFormat.mFormatFlags       = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
    sint16StreamFormat.mBytesPerPacket    = bytesPerSample * _channels;
    sint16StreamFormat.mFramesPerPacket   = 1;
    sint16StreamFormat.mBytesPerFrame     = bytesPerSample * _channels;
    sint16StreamFormat.mChannelsPerFrame  = _channels;
    sint16StreamFormat.mBitsPerChannel    = 8 * bytesPerSample;
    // 2-2: 设置转换器单元的输入流格式
    status = AudioUnitSetProperty(_convertUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  element0,
                                  &sint16StreamFormat,
                                  sizeof(sint16StreamFormat));
    CheckStatus(status, @"convert unit set sint16 format error", YES);
    // 2-2: 设置转换器单元的输出流格式
    status = AudioUnitSetProperty(_convertUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Output,
                                  element0,
                                  &float32StreamFormat,
                                  sizeof(float32StreamFormat));
    CheckStatus(status, @"convert unit set float32 format error", YES);
}

- (void)makeNodeConnections {
    OSStatus status = noErr;
    // 连接输入结点和转换器结点
    status = AUGraphConnectNodeInput(_auGraph, _convertNode, element0, _ioNode, element0);
    CheckStatus(status, @"Could not connect convert node input to I/O node input", YES);
    // 创建渲染回调
    AURenderCallbackStruct callbackStruct;
    callbackStruct.inputProc = &InputRenderCallback; // 函数入口
    callbackStruct.inputProcRefCon = (__bridge void *)self; // 参数传递
    // 设置转换器单元的渲染回调
    status = AudioUnitSetProperty(_convertUnit,
                                  kAudioUnitProperty_SetRenderCallback,
                                  kAudioUnitScope_Input,
                                  element0,
                                  &callbackStruct,
                                  sizeof(callbackStruct));
    CheckStatus(status, @"Could not set render callback on convert input scope, element 0", YES);
}

- (void)destroyAudioUnitGraph {
    AUGraphStop(_auGraph);
    AUGraphUninitialize(_auGraph);
    AUGraphClose(_auGraph);
    AUGraphRemoveNode(_auGraph, _ioNode);
    DisposeAUGraph(_auGraph);
    _ioUnit = NULL;
    _ioNode = 0;
    _auGraph = NULL;
}

#pragma mark - 音频渲染方法
static OSStatus InputRenderCallback(void *inRefCon,
                                    AudioUnitRenderActionFlags *ioActionFlags,
                                    const AudioTimeStamp *inTimeStamp,
                                    UInt32 inBusNumber,
                                    UInt32 inNumberFrames,
                                    AudioBufferList *ioData) {
    AUAudioOutput *audioOutput = (__bridge id)inRefCon;
    return [audioOutput renderData:ioData
                       atTimeStamp:inTimeStamp
                        forElement:inBusNumber
                      numberFrames:inNumberFrames
                             flags:ioActionFlags];
}

/// 音频渲染方法
/// @param ioData 输出数据
/// @param timeStamp 时间戳
/// @param element 元素(XX控制端)
/// @param numFrames 帧数
/// @param flags 音频渲染方式
- (OSStatus)renderData:(AudioBufferList *)ioData
           atTimeStamp:(const AudioTimeStamp *)timeStamp
            forElement:(UInt32)element
          numberFrames:(UInt32)numFrames
                 flags:(AudioUnitRenderActionFlags *)flags {
    // 清空当前数据
    for (int iBuffer = 0; iBuffer < ioData->mNumberBuffers; ++iBuffer) {
        memset(ioData->mBuffers[iBuffer].mData, 0, ioData->mBuffers[iBuffer].mDataByteSize);
    }
    
    // 通过代理填充数据
    if(_fillAudioDataDelegate) {
        [_fillAudioDataDelegate fillAudioData:_outData numFrames:numFrames numChannels:_channels];
        for (int iBuffer = 0; iBuffer < ioData->mNumberBuffers; ++iBuffer) {
            memcpy((SInt16 *)ioData->mBuffers[iBuffer].mData, _outData, ioData->mBuffers[iBuffer].mDataByteSize);
        }
    }
    return noErr;
}

@end
