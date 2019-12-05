//
//  SCAudioOutput.m
//  AudioPlayer
//
//  Created by SeacenLiu on 2019/11/14.
//  Copyright © 2019 SeacenLiu. All rights reserved.
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
* 1: 通过AudioComponentDescription创建AudioUnit实例
* 2: 通过AudioStreamBasicDescription配置AudioUnit属性
* 3: 连接AudioUnit中的结点或设置RenderCallback
* 4: 初始化AudioUnit
* 5: 启动AudioOutput
*
* * 音频图结构
*   InputRenderCallback->(clientFormat16int)->convertNodoOutputElement->(streamFormat)
*   ->"AUGraphConnectNodeInput"->
*   ioNodeInputElement->(streamFormat)->ioNodeOutputElement->扬声器/耳机播放
**/

#import "SCAudioOutput.h"
#import <AudioToolbox/AudioToolbox.h>
#import <Accelerate/Accelerate.h>
#import "SCAudioSession.h"
#import "CommonUtil.h"

// 输入控制端
static const AudioUnitElement inputElement = 1;
// 输出控制端
static const AudioUnitElement outputElement = 0;

// 输入回调函数声明
static OSStatus InputRenderCallback(void *inRefCon,
                                    AudioUnitRenderActionFlags *ioActionFlags,
                                    const AudioTimeStamp *inTimeStamp,
                                    UInt32 inBusNumber,
                                    UInt32 inNumberFrames,
                                    AudioBufferList *ioData);
// 状态检查函数声明
static void CheckStatus(OSStatus status, NSString *message, BOOL fatal);

@interface SCAudioOutput () {
    // 输出数据
    SInt16*                      _outData;
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
@property (readwrite, weak) id<SCFillDataDelegate> fillAudioDataDelegate;

@end

const float SMAudioIOBufferDurationSmall = 0.0058f;

@implementation SCAudioOutput

#pragma mark - life cycle
- (instancetype)initWithChannels:(NSInteger)channels
                      sampleRate:(NSInteger)sampleRate
                  bytesPerSample:(NSInteger)bytePerSample
               filleDataDelegate:(id<SCFillDataDelegate>)fillAudioDataDelegate {
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
        // 8192 个长度为2个字节的数组(2^13 = 8192), SInt16(signed short)
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

#pragma mark - 音频单元图
- (void)createAudioUnitGraph {
    OSStatus status = noErr;
    // 1. 创建音频图
    status = NewAUGraph(&_auGraph);
    CheckStatus(status, @"Could not create a new AUGraph", YES);
    // 2. 添加音频结点
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
    NSLog(@"CAShow: ------");
    CAShow(_auGraph);
    NSLog(@"CAShow: ------");
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
    // 2-1: 定义转化器描述
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
    // 1-1: 定义音频流格式
    AudioStreamBasicDescription streamFormat;
    UInt32 bytesPerSample = sizeof(Float32);
    bzero(&streamFormat, sizeof(streamFormat));
    streamFormat.mSampleRate             = _sampleRate;
    streamFormat.mFormatID               = kAudioFormatLinearPCM;
    streamFormat.mFormatFlags            = kAudioFormatFlagsNativeFloatPacked | kAudioFormatFlagIsNonInterleaved;
    streamFormat.mBytesPerPacket         = bytesPerSample;
    streamFormat.mFramesPerPacket        = 1;
    streamFormat.mBytesPerFrame          = bytesPerSample;
    streamFormat.mChannelsPerFrame       = _channels;
    streamFormat.mBitsPerChannel         = 8 * bytesPerSample;
    // 1-2: 设置I/O单元在inputElement的输出流端的输入域流格式
    status = AudioUnitSetProperty(_ioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Output,
                                  inputElement,
                                  &streamFormat,
                                  sizeof(streamFormat));
    // 2. 设置转换器单元属性
    // 2-1: 定义客户端流格式
    AudioStreamBasicDescription clientFormat16int;
    bytesPerSample = sizeof (SInt16);
    bzero(&clientFormat16int, sizeof(clientFormat16int));
    clientFormat16int.mSampleRate        = _sampleRate;
    clientFormat16int.mFormatID          = kAudioFormatLinearPCM;
    clientFormat16int.mFormatFlags       = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
    clientFormat16int.mBytesPerPacket    = bytesPerSample * _channels;
    clientFormat16int.mFramesPerPacket   = 1;
    clientFormat16int.mBytesPerFrame     = bytesPerSample * _channels;
    clientFormat16int.mChannelsPerFrame  = _channels;
    clientFormat16int.mBitsPerChannel    = 8 * bytesPerSample;
    // 2-2: 设置转换器单元的输出端输出域的流格式
    status = AudioUnitSetProperty(_convertUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Output,
                                  outputElement,
                                  &streamFormat,
                                  sizeof(streamFormat));
    CheckStatus(status, @"augraph recorder normal unit set client format error", YES);
    // 2-3: 设置转换器单元的输出端输入域的流格式
    status = AudioUnitSetProperty(_convertUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  outputElement,
                                  &clientFormat16int,
                                  sizeof(clientFormat16int));
    CheckStatus(status, @"augraph recorder normal unit set client format error", YES);
    // 转换器: 输入端输入域->输入端输出域->输出端输入域(clientFormat16int)->输出端输出域(streamFormat)
    // IO单元: 麦克风->输入端输入域->输入端输出域(streamFormat)->应用->输出端输入域->输出端输出域
}

- (void)makeNodeConnections {
    OSStatus status = noErr;
    // 连接输入结点和转换器结点
    // 将 _convertNode 输出端链接在 _ioNode 的输入端
    status = AUGraphConnectNodeInput(_auGraph, _convertNode, 0, _ioNode, 0);
    CheckStatus(status, @"Could not connect I/O node input to mixer node output", YES);
    // *** 创建渲染回调 ***
    AURenderCallbackStruct callbackStruct;
    callbackStruct.inputProc = &InputRenderCallback; // 函数入口
    callbackStruct.inputProcRefCon = (__bridge void *)self; // 参数传递
    // 设置转换器单元的渲染回调(输出端输入域)
    status = AudioUnitSetProperty(_convertUnit,
                                  kAudioUnitProperty_SetRenderCallback,
                                  kAudioUnitScope_Input,
                                  outputElement,
                                  &callbackStruct,
                                  sizeof(callbackStruct));
    CheckStatus(status, @"Could not set render callback on mixer input scope, element 1", YES);
}

#pragma mark - Method
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

#pragma mark - Observer
- (void)addAudioSessionInterruptedObserver {
    [self removeAudioSessionInterruptedObserver];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onNotificationAudioInterrupted:)
                                                 name:AVAudioSessionInterruptionNotification
                                               object:[AVAudioSession sharedInstance]];
}

- (void)removeAudioSessionInterruptedObserver {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AVAudioSessionInterruptionNotification
                                                  object:nil];
}

- (void)onNotificationAudioInterrupted:(NSNotification *)sender {
    AVAudioSessionInterruptionType interruptionType = [[[sender userInfo] objectForKey:AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];
    switch (interruptionType) {
        case AVAudioSessionInterruptionTypeBegan: // 打断开始
            [self stop];
            break;
        case AVAudioSessionInterruptionTypeEnded: // 打断结束
            [self play];
            break;
        default:
            break;
    }
}

#pragma mark - 音频渲染方法
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
    for (int iBuffer = 0; iBuffer < ioData->mNumberBuffers; ++iBuffer) {
        memset(ioData->mBuffers[iBuffer].mData, 0, ioData->mBuffers[iBuffer].mDataByteSize);
    }
    if (_fillAudioDataDelegate) {
        [_fillAudioDataDelegate fillAudioData:_outData numFrames:numFrames numChannels:_channels];
        for (int iBuffer = 0; iBuffer < ioData->mNumberBuffers; ++iBuffer) {
            // 将 _outData 拷贝到 ioData->mBuffers[iBuffer].mData 中
            memcpy((SInt16 *)ioData->mBuffers[iBuffer].mData, _outData, ioData->mBuffers[iBuffer].mDataByteSize);
        }
    }
    return noErr;
}

@end

#pragma mark - C语言工具函数实现
static OSStatus InputRenderCallback(void *inRefCon,
                                    AudioUnitRenderActionFlags *ioActionFlags,
                                    const AudioTimeStamp *inTimeStamp,
                                    UInt32 inBusNumber,
                                    UInt32 inNumberFrames,
                                    AudioBufferList *ioData) {
    SCAudioOutput *audioOutput = (__bridge id)inRefCon;
    return [audioOutput renderData:ioData
                 atTimeStamp:inTimeStamp
                  forElement:inBusNumber
                numberFrames:inNumberFrames
                       flags:ioActionFlags];
}

static void CheckStatus(OSStatus status, NSString *message, BOOL fatal) {
    if(status != noErr)
    {
        char fourCC[16];
        *(UInt32 *)fourCC = CFSwapInt32HostToBig(status);
        fourCC[4] = '\0';
        
        if(isprint(fourCC[0]) && isprint(fourCC[1]) && isprint(fourCC[2]) && isprint(fourCC[3]))
            NSLog(@"%@: %s", message, fourCC);
        else
            NSLog(@"%@: %d", message, (int)status);
        
        if(fatal)
            exit(-1);
    }
}
