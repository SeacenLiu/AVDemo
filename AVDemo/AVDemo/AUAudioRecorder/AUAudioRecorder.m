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
@property (nonatomic, assign) AUNode             mixerNode;
@property (nonatomic, assign) AudioUnit          mixerUnit;
@property (nonatomic, assign) AUNode             convertNode;
@property (nonatomic, assign) AudioUnit          convertUnit;

@property (nonatomic, assign, getter=isEnablePlayWhenRecord) BOOL enablePlayWhenRecord;

@end

#define BufferList_cache_size (1024*10*5)
@implementation AUAudioRecorder
{
    AUExtAudioFile *audioFile;
    AudioBufferList *_bufferList;
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
    DestroyBufferList(_bufferList);
}

#pragma mark - public method
- (void)start {
    AudioStreamBasicDescription clientFormat;
    UInt32 fSize = sizeof (clientFormat);
    memset(&clientFormat, 0, sizeof(clientFormat));
    CheckStatus(AudioUnitGetProperty(_ioUnit,
                                     kAudioUnitProperty_StreamFormat,
                                     kAudioUnitScope_Output,
                                     inputElement,
                                     &clientFormat,
                                     &fSize),
                @"AudioUnitGetProperty on failed",
                YES);
    NSLog(@"---------------------- clientFormat --------------------------");
    printAudioStreamFormat(clientFormat);
    audioFile = [[AUExtAudioFile alloc] initWithWritePath:_filePath adsb:clientFormat fileTypeId:AUAudioFileTypeCAF];
    
    OSStatus status = AUGraphStart(_auGraph);
    CheckStatus(status, @"启动音频图失败", YES);
}

- (void)stop {
    OSStatus status = AUGraphStop(_auGraph);
    CheckStatus(status, @"停止音频图失败", YES);
    // 关闭文件和释放对象
    [audioFile closeFile];
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

- (void)getUnitsFromNodes {
    OSStatus status = noErr;
    status = AUGraphNodeInfo(_auGraph, _ioNode, NULL, &_ioUnit);
    CheckStatus(status, @"获取RemoteIO单元失败", YES);
    status = AUGraphNodeInfo(_auGraph, _mixerNode, NULL, &_mixerUnit);
    CheckStatus(status, @"获取Mixer单元失败", YES);
    status = AUGraphNodeInfo(_auGraph, _convertNode, NULL, &_convertUnit);
    CheckStatus(status, @"获取Convert单元失败", YES);
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
    UInt32 maximumFramesPerSlice = 4096;
    status = AudioUnitSetProperty(_ioUnit,
                                  kAudioUnitProperty_MaximumFramesPerSlice,
                                  kAudioUnitScope_Global,
                                  outputElement,
                                  &maximumFramesPerSlice,
                                  sizeof (maximumFramesPerSlice));
    CheckStatus(status, @"RemoteIO 切片最大帧数设置失败", YES);
    // 设置音频图中的音频流格式
    AudioStreamBasicDescription linearPCMFormat;
    AudioFormatFlags formatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    linearPCMFormat = linearPCMStreamDes(formatFlags,
                                         _sampleRate,
                                         2,
                                         sizeof(UInt16));
    NSLog(@"---------------------- linearPCMFormat --------------------------");
    printAudioStreamFormat(linearPCMFormat);
    
    // RemoteIO 流格式
    AudioUnitSetProperty(_ioUnit,
                         kAudioUnitProperty_StreamFormat,
                         kAudioUnitScope_Output,
                         inputElement,
                         &linearPCMFormat,
                         sizeof(linearPCMFormat));
}

- (void)makeNodeConnections {
    OSStatus status = noErr;
    if (self.isEnablePlayWhenRecord) {
        status = AUGraphConnectNodeInput(_auGraph,
                                         _ioNode, inputElement,
                                         _ioNode, outputElement);
    }
}

- (void)setupRenderCallback {
    OSStatus status;
    AURenderCallbackStruct finalRenderProc;
    finalRenderProc.inputProc = &RenderCallback;
    finalRenderProc.inputProcRefCon = (__bridge void *)self;
    status = AudioUnitSetProperty(_ioUnit,
                                  kAudioOutputUnitProperty_SetInputCallback,
                                  kAudioUnitScope_Output,
                                  inputElement,
                                  &finalRenderProc,
                                  sizeof(finalRenderProc));
    CheckStatus(status, @"设置 RemoteIO 输出回调失败", YES);
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
static OSStatus RenderCallback(void *inRefCon,
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
                    inBusNumber,
                    inNumberFrames,
                    recorder->_bufferList);
    
    // 异步向文件中写入数据
    result = [recorder->audioFile writeFrames:inNumberFrames
                                 toBufferData:recorder->_bufferList
                                        async:YES];
    
    return result;
}

@end
