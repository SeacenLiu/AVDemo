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

// 录音属性
@property (nonatomic, copy)   NSString*          filePath;
@property (nonatomic, assign) Float64            sampleRate;
@property (nonatomic, assign) UInt32             channels;

// ioUnit
@property (nonatomic, assign) AudioComponent         ioComponent;
@property (nonatomic, assign) AudioComponentInstance ioComponentInstance; // AudioUnit ioUnit

// 文件保存
@property (nonatomic, strong) AUExtAudioFile*        dataWriter;

// 录音任务队列
@property (nonatomic, strong) dispatch_queue_t       recordTaskQueue;

@end

#define BufferList_cache_size (1024*10*5)
@implementation AUAudioRecorder {
    AudioBufferList* _bufferList;
}

#pragma mark - init
- (instancetype)initWithPath:(NSString *)path {
    if (self = [super init]) {
        // 属性初始化
        _filePath = path;
        _sampleRate = 44100.0;
        _channels = 2;
        _bufferList = CreateBufferList(_channels, NO, BufferList_cache_size);
        _recordTaskQueue = dispatch_queue_create("com.seacen.record.task.Queue", NULL);
        
        // 音频会话设置
        [[SCAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord];
        [[SCAudioSession sharedInstance] setPreferredSampleRate:_sampleRate];
        [[SCAudioSession sharedInstance] setActive:YES];
        [[SCAudioSession sharedInstance] addRouteChangeListener];
        
        // 音频打断处理
        [self addAudioSessionInterruptedObserver];
        
        // 创建音频组件描述
        OSStatus status = noErr;
        AudioComponentDescription ioDescription;
        bzero(&ioDescription, sizeof(ioDescription));
        ioDescription.componentType = kAudioUnitType_Output;
        ioDescription.componentSubType = kAudioUnitSubType_RemoteIO;
        ioDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
        ioDescription.componentFlags = 0;
        ioDescription.componentFlagsMask = 0;
        
        // 获取音频组件类（即音频单元的类）
        _ioComponent = AudioComponentFindNext(NULL, &ioDescription);
        
        // 实例化音频组件（即音频单元）
        status = AudioComponentInstanceNew(_ioComponent, &_ioComponentInstance);
        CheckStatus(status, @"RemoteIO结点添加失败", YES);
        
        // 配置音频单元的属性
        // 打开麦克风
        UInt32 enableIO = 1;
        status = AudioUnitSetProperty(_ioComponentInstance,
                                      kAudioOutputUnitProperty_EnableIO,
                                      kAudioUnitScope_Input,
                                      inputElement,
                                      &enableIO,
                                      sizeof(enableIO));
        CheckStatus(status, @"打开麦克风失败", YES);
        // 打开扬声器
        status = AudioUnitSetProperty(_ioComponentInstance,
                                      kAudioOutputUnitProperty_EnableIO,
                                      kAudioUnitScope_Output,
                                      outputElement,
                                      &enableIO,
                                      sizeof(enableIO));
        CheckStatus(status, @"打开扬声器失败", YES);
        // 音频流设置
        AudioStreamBasicDescription linearPCMStreamFormat;
        linearPCMStreamFormat = [self getLinearPCMStreamFormat];
        status = AudioUnitSetProperty(_ioComponentInstance,
                                      kAudioUnitProperty_StreamFormat,
                                      kAudioUnitScope_Output,
                                      inputElement,
                                      &linearPCMStreamFormat,
                                      sizeof(linearPCMStreamFormat));
        CheckStatus(status, @"配置输入元件输出端流格式失败", YES);
        status = AudioUnitSetProperty(_ioComponentInstance,
                                      kAudioUnitProperty_StreamFormat,
                                      kAudioUnitScope_Input,
                                      outputElement,
                                      &linearPCMStreamFormat,
                                      sizeof(linearPCMStreamFormat));
        CheckStatus(status, @"配置输出元件输入端流格式失败", YES);
        // 音频保存回调
        AURenderCallbackStruct inputCallbackProc;
        inputCallbackProc.inputProc = &inputaCallback;
        inputCallbackProc.inputProcRefCon = (__bridge void *)self;
        status = AudioUnitSetProperty(_ioComponentInstance,
                                      kAudioOutputUnitProperty_SetInputCallback,
                                      kAudioUnitScope_Global,
                                      inputElement,
                                      &inputCallbackProc,
                                      sizeof(inputCallbackProc));
        CheckStatus(status, @"配置输入元件全局端回调失败", YES);
        
        AURenderCallbackStruct renderCallbackProc;
        renderCallbackProc.inputProc = &renderCallbackCallback;
        renderCallbackProc.inputProcRefCon = (__bridge void *)self;
        status = AudioUnitSetProperty(_ioComponentInstance,
                                      kAudioUnitProperty_SetRenderCallback,
                                      kAudioUnitScope_Input,
                                      outputElement,
                                      &renderCallbackProc,
                                      sizeof(renderCallbackProc));
        CheckStatus(status, @"配置输出元件输入端回调失败", YES);
        
        // 音频单元初始化
        status = AudioUnitInitialize(_ioComponentInstance);
        CheckStatus(status, @"音频单元初始化失败", YES);
    }
    return self;
}

- (void)dealloc {
    _ioComponentInstance = NULL;
}

#pragma mark - public method
- (void)startRecord {
    dispatch_async(self.recordTaskQueue, ^{
        self.dataWriter = [[AUExtAudioFile alloc] initWithWritePath:self.filePath
                                                               adsb:[self getLinearPCMStreamFormat]
                                                         fileTypeId:AUAudioFileTypeCAF];
        OSStatus status = AudioOutputUnitStart(self.ioComponentInstance);
        CheckStatus(status, @"io unit 启动失败", YES);
    });
}

- (void)stopRecord {
    dispatch_async(self.recordTaskQueue, ^{
        OSStatus status = AudioOutputUnitStop(self.ioComponentInstance);
        CheckStatus(status, @"io unit 停止失败", YES);
        
        // 关闭文件和释放对象
        [self.dataWriter closeFile];
    });
}

#pragma mark - private metho
static OSStatus inputaCallback(void *inRefCon,
                                 AudioUnitRenderActionFlags *ioActionFlags,
                                 const AudioTimeStamp *inTimeStamp,
                                 UInt32 inBusNumber,
                                 UInt32 inNumberFrames,
                                 AudioBufferList *ioData) {
    OSStatus result = noErr;
    __unsafe_unretained AUAudioRecorder *recorder = (__bridge AUAudioRecorder *)inRefCon;
    
    result = AudioUnitRender(recorder->_ioComponentInstance,
                             ioActionFlags,
                             inTimeStamp,
                             inputElement,
                             inNumberFrames,
                             recorder->_bufferList);
    
    result = [recorder->_dataWriter writeFrames:inNumberFrames
                                   toBufferData:recorder->_bufferList
                                          async:YES];
    
    return result;
}

static OSStatus renderCallbackCallback(void *inRefCon,
                                       AudioUnitRenderActionFlags *ioActionFlags,
                                       const AudioTimeStamp *inTimeStamp,
                                       UInt32 inBusNumber,
                                       UInt32 inNumberFrames,
                                       AudioBufferList *ioData) {
    OSStatus result = noErr;
    __unsafe_unretained AUAudioRecorder *recorder = (__bridge AUAudioRecorder *)inRefCon;
    
    /** 本 Demo 将音频渲染与保存操作交给 inputaCallback 完成
     result = AudioUnitRender(recorder->_ioComponentInstance,
                              ioActionFlags,
                              inTimeStamp,
                              inputElement,
                              inNumberFrames,
                              recorder->_bufferList);
     result = [recorder->_dataWriter writeFrames:inNumberFrames
                                    toBufferData:recorder->_bufferList
                                           async:YES];
     */
    
    if (recorder->_enablePlayWhenRecord) {
        CopyInterleavedBufferList(ioData, recorder->_bufferList);
    } else {
        SilenceInterleavedBufferList(ioData);
    }
    
    return result;
}

- (AudioStreamBasicDescription)getLinearPCMStreamFormat {
    AudioStreamBasicDescription micInputStreamFormat;
    AudioFormatFlags formatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked;
    micInputStreamFormat = linearPCMStreamDes(formatFlags,
                                              _sampleRate,
                                              _channels,
                                              sizeof(UInt16));
    return micInputStreamFormat;
}


@end
