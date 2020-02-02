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
@property (nonatomic, assign) UInt32          channels;

@property (nonatomic, assign) AUGraph            auGraph;
@property (nonatomic, assign) AUNode             ioNode;
@property (nonatomic, assign) AudioUnit          ioUnit;
@property (nonatomic, assign) AUNode             mixerNode;
@property (nonatomic, assign) AudioUnit          mixerUnit;
@property (nonatomic, assign) AUNode             convertNode;
@property (nonatomic, assign) AudioUnit          convertUnit;

@end

@implementation AUAudioRecorder
{
    AUExtAudioFile *audioFile;
}

#pragma mark - life cycle
- (instancetype)initWithPath:(NSString*)path {
    if (self = [self init]) {
        // 属性初始化
        _filePath = path;
        _sampleRate = 44100.0;
        _channels = 2;
        
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
}

#pragma mark - public method
- (void)start {
    AudioStreamBasicDescription clientFormat;
    UInt32 fSize = sizeof (clientFormat);
    memset(&clientFormat, 0, sizeof(clientFormat));
    CheckStatus(AudioUnitGetProperty(_mixerUnit,
                                     kAudioUnitProperty_StreamFormat,
                                     kAudioUnitScope_Output,
                                     outputElement,
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
    // 激活 RemoteIO 的 IO 功能（输入端输入域）
    UInt32 enableIO = 1;
    status = AudioUnitSetProperty(_ioUnit,
                                  kAudioOutputUnitProperty_EnableIO,
                                  kAudioUnitScope_Input,
                                  inputElement,
                                  &enableIO,
                                  sizeof(enableIO));
    CheckStatus(status, @"RemoteIO IO 启动失败", YES);
    // 设置 Mixer 输出流数量（输出端输入域）
    UInt32 mixerElementCount = 1;
    status = AudioUnitSetProperty(_mixerUnit,
                                  kAudioUnitProperty_ElementCount,
                                  kAudioUnitScope_Input,
                                  outputElement,
                                  &mixerElementCount,
                                  sizeof(mixerElementCount));
    CheckStatus(status, @"Mixer 元素数量设置失败", YES);
    // 设置 Mixer 的采集率（输出端输出域）
    status = AudioUnitSetProperty(_mixerUnit,
                                  kAudioUnitProperty_SampleRate,
                                  kAudioUnitScope_Output,
                                  outputElement,
                                  &_sampleRate,
                                  sizeof(_sampleRate));
    CheckStatus(status, @"Mixer 采集率设置失败", YES);
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
    // 录制音频流格式
    AudioStreamBasicDescription recordASDB;
    AudioFormatFlags recordFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsNonInterleaved;
    recordASDB = linearPCMStreamDes(recordFlags, _sampleRate, _channels, sizeof(UInt16));
    //
    
    AudioStreamBasicDescription linearPCMFormat;
    AudioFormatFlags formatFlags = kAudioFormatFlagsNativeFloatPacked | kAudioFormatFlagIsNonInterleaved;
    linearPCMFormat = linearPCMStreamDes(formatFlags,
                                         _sampleRate,
                                         2,
                                         sizeof(Float32));
    NSLog(@"---------------------- linearPCMFormat --------------------------");
    printAudioStreamFormat(linearPCMFormat);
    
    // RemoteIO 流格式
    AudioUnitSetProperty(_ioUnit,
                         kAudioUnitProperty_StreamFormat,
                         kAudioUnitScope_Input,
                         outputElement,
                         &linearPCMFormat,
                         sizeof(linearPCMFormat));
    
    // Convert 流格式
    AudioUnitSetProperty(_convertUnit,
                         kAudioUnitProperty_StreamFormat,
                         kAudioUnitScope_Input,
                         outputElement,
                         &linearPCMFormat,
                         sizeof(linearPCMFormat));
    
    AudioUnitSetProperty(_convertUnit,
                         kAudioUnitProperty_StreamFormat,
                         kAudioUnitScope_Output,
                         outputElement,
                         &linearPCMFormat,
                         sizeof(linearPCMFormat));
    
    // Mixer 流格式
    AudioUnitSetProperty(_mixerUnit,
                         kAudioUnitProperty_StreamFormat,
                         kAudioUnitScope_Input,
                         outputElement,
                         &linearPCMFormat,
                         sizeof(linearPCMFormat));
    
    // RemoteIO 流格式
    AudioUnitSetProperty(_ioUnit,
                         kAudioUnitProperty_StreamFormat,
                         kAudioUnitScope_Output,
                         inputElement,
                         &linearPCMFormat,
                         sizeof(linearPCMFormat));
    /**
     *
     * RemoteIO(InputElement) -stereoStreamFormat->
     *
     * -stereoStreamFormat-> Convert(OutputElement)
     * Convert(OutputElement) -clientFormat32float->
     *
     * -clientFormat32float-> Mixer(OutputElement)
     *
     * -clientFormat32float-> _RemoteIO(OutputElement)
     */
}

- (void)makeNodeConnections {
    /**
     * _ioNode(InputElement)->_convertNode(OutputElement)->
     * _mixerNode(OutputElement)->_ioNode(OutputElement)
     */
    OSStatus status = noErr;
    // 连接 RemoteIO 的输入端到 Convert 的输出端
    status = AUGraphConnectNodeInput(_auGraph,
                                     _ioNode, inputElement,
                                     _convertNode, outputElement);
    CheckStatus(status, @"连接 RemoteIO 的输出到 Convert 的输入失败", YES);
    //  连接 Convert 的输出端到 Mixer 的输入端
    status = AUGraphConnectNodeInput(_auGraph,
                                     _convertNode, outputElement,
                                     _mixerNode, outputElement);
    CheckStatus(status, @"连接 Convert 的输出到 Mixer 的输入失败", YES);
    // _mixerNode(OutputElement)->_ioNode(OutputElement) 是后续通过RenderCallBack获取的
    
}

- (void)setupRenderCallback {
    OSStatus status;
    AURenderCallbackStruct finalRenderProc;
    finalRenderProc.inputProc = &RenderCallback;
    finalRenderProc.inputProcRefCon = (__bridge void *)self;
    status = AUGraphSetNodeInputCallback(_auGraph,
                                         _ioNode,
                                         outputElement,
                                         &finalRenderProc);
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

    // 将 Mixer 输出的音频数据渲染到 ioData，即连接了 Mixer 与 RemoteIO(OutputElement)
    AudioUnitRender(recorder->_mixerUnit,
                    ioActionFlags,
                    inTimeStamp,
                    outputElement,
                    inNumberFrames,
                    ioData);
    
    // 异步向文件中写入数据
    result = [recorder->audioFile writeFrames:inNumberFrames toBufferData:ioData async:YES];
    
    return result;
}

@end
