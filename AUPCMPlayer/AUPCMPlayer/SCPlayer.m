//
//  SCPlayer.m
//  AUPCMPlayer
//
//  Created by bobo on 2019/12/4.
//  Copyright © 2019年 seacenliu. All rights reserved.
//

#import "SCPlayer.h"
#import <AudioUnit/AudioUnit.h>
#import <AVFoundation/AVFoundation.h>
#import <assert.h>

const uint32_t CONST_BUFFER_SIZE = 0x10000;

#define INPUT_BUS 1
#define OUTPUT_BUS 0

@interface SCPlayer ()
@property (nonatomic, strong) NSURL *fileURL;
@end

@implementation SCPlayer
{
    AudioUnit _audioUnit;         // 音频单元
    AudioBufferList *_buffList;   // 音频的缓存数据结构
    
    NSInputStream *_inputSteam;   // 输入流
}

- (instancetype)initWithFileURL:(NSURL *)fileURL {
    if (self = [self init]) {
        _fileURL = fileURL;
    }
    return self;
}

- (void)play {
    // 按照状态进行播放器准备
    [self preparePlayer];
    
    // 调用 AudioOutputUnitStart 开始
    // AudioUnit 会调用之前设置的 PlayCallback，
    // 在回调函数中把音频数据赋值给 AudioBufferList
    OSStatus status = AudioOutputUnitStart(_audioUnit);
    if (status == noErr) {
        _status = SCPlayerStatusPlay;
        if (self.delegate && [self.delegate respondsToSelector:@selector(onPlayerRefreshStatus:status:)]) {
            [self.delegate onPlayerRefreshStatus:self status:SCPlayerStatusPlay];
        }
    } else {
        NSLog(@"播放失败, %d", status);
    }
}

- (void)stop {
    OSStatus status = AudioOutputUnitStop(_audioUnit);
    if (status == noErr) {
        _status = SCPlayerStatusStop;
        if (self.delegate && [self.delegate respondsToSelector:@selector(onPlayerRefreshStatus:status:)]) {
            [self.delegate onPlayerRefreshStatus:self status:SCPlayerStatusStop];
        }
    } else {
        NSLog(@"暂停失败, %d", status);
        return;
    }
}

- (void)end {
    OSStatus status = AudioOutputUnitStop(_audioUnit);
    if (status == noErr) {
        _status = SCPlayerStatusEnd;
        if (self.delegate && [self.delegate respondsToSelector:@selector(onPlayerRefreshStatus:status:)]) {
            [self.delegate onPlayerRefreshStatus:self status:SCPlayerStatusEnd];
        }
        if (_buffList != NULL) {
            if (_buffList->mBuffers[0].mData) {
                free(_buffList->mBuffers[0].mData);
                _buffList->mBuffers[0].mData = NULL;
            }
            free(_buffList);
            _buffList = NULL;
        }
        [_inputSteam close];
    } else {
        NSLog(@"暂停失败, %d", status);
        return;
    }
}

- (void)preparePlayer {
    // 播放过程中不需要进行重新准备
    if (_status == SCPlayerStatusPlay ||
        _status == SCPlayerStatusStop) {
        return;
    }
    // 从文件中读取输入流
    _inputSteam = [NSInputStream inputStreamWithURL:_fileURL];
    if (!_inputSteam) {
        NSLog(@"打开文件失败 %@", _fileURL);
        return;
    } else {
        [_inputSteam open];
    }
    // 设置全局的 Audio Session
    [self setupAudioSession];
    // 初始化缓冲区
    _buffList = [self createBuffList];
    // 配置 AudioUnit
    [self setupAudioUnit];
}

- (void)setupAudioSession {
    NSError *error = nil;
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayback
                  withOptions:AVAudioSessionCategoryOptionAllowBluetoothA2DP
                        error:&error];
}

- (AudioBufferList *)createBuffList {
    AudioBufferList *buffList = (AudioBufferList *)malloc(sizeof(AudioBufferList));
    buffList->mNumberBuffers = 1;                             // 缓冲数量
    buffList->mBuffers[0].mNumberChannels = 1;                // 声道数
    buffList->mBuffers[0].mDataByteSize = CONST_BUFFER_SIZE;  // 一个缓存的大小
    buffList->mBuffers[0].mData = malloc(CONST_BUFFER_SIZE);  // 数据大小
    return buffList;
}

/**
extern OSStatus // 返回状态位
AudioUnitSetProperty(// 音频单元对象
                     AudioUnit                  inUnit,
                     // 属性名称枚举
                     AudioUnitPropertyID        inID,
                     // 域枚举
                     AudioUnitScope             inScope,
                     // 元素(输入1,输出0)
                     AudioUnitElement           inElement,
                     // 值(null为置0或移除之前的值，大部分属性有初始值)
                     const void * __nullable    inData,
                     // 值得长度
                     UInt32                     inDataSize)
API_AVAILABLE(macos(10.0), ios(2.0), watchos(2.0), tvos(9.0));
 */
- (void)setupAudioUnit {
    // 创建 RemoteIO 实例
    // 1. 对 RemoteIO 组件进行描述
    AudioComponentDescription audioDesc;
    audioDesc.componentType = kAudioUnitType_Output;
    audioDesc.componentSubType = kAudioUnitSubType_RemoteIO;
    audioDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    audioDesc.componentFlags = 0;
    audioDesc.componentFlagsMask = 0;
    // 2. 创建 RemoteIO 组件
    AudioComponent inputComponent = AudioComponentFindNext(NULL, &audioDesc);
    // 3. 用 RemoteIO 组件实例化音频单元
    AudioComponentInstanceNew(inputComponent, &_audioUnit);
    // 4. 激活 RemoteIO 的输出端的输出域功能
    OSStatus status = noErr;
    UInt32 flag = 1;
    if (flag) {
        status = AudioUnitSetProperty(_audioUnit,
                                      kAudioOutputUnitProperty_EnableIO,
                                      kAudioUnitScope_Output,
                                      OUTPUT_BUS,
                                      &flag,
                                      sizeof(flag));
    }
    if (status) {
        NSLog(@"AudioUnitSetProperty error with status: %d", status);
    }
    // 5. 描述输出流的格式
    AudioStreamBasicDescription outputFormat;
    memset(&outputFormat, 0, sizeof(outputFormat));
    outputFormat.mSampleRate = 44100; // 采集率
    outputFormat.mFormatID = kAudioFormatLinearPCM; // PCM 格式
    outputFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger; // 整形
    outputFormat.mFramesPerPacket = 1; // 每帧只有1个packet
    outputFormat.mChannelsPerFrame = 2; // 声道数
    outputFormat.mBytesPerPacket = 2; // 每个Packet只有2个byte
    outputFormat.mBytesPerFrame = 4; // 每帧只有2个byte 声道*Packet数*Packet大小
    outputFormat.mBitsPerChannel = 16; // 位深
    // 6. 设置 RemoteIO 输出端的输入域流格式
    status = AudioUnitSetProperty(_audioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  OUTPUT_BUS,
                                  &outputFormat,
                                  sizeof(outputFormat));
    if (status) {
        NSLog(@"AudioUnitSetProperty error with status: %d", status);
    }
    // 7. 设置输出端的输入域渲染回调
    AURenderCallbackStruct playCallback;
    playCallback.inputProc = PlayCallback;
    playCallback.inputProcRefCon = (__bridge void *)self;
    AudioUnitSetProperty(_audioUnit,
                         kAudioUnitProperty_SetRenderCallback,
                         kAudioUnitScope_Input,
                         OUTPUT_BUS,
                         &playCallback,
                         sizeof(playCallback));
    // 8. 初始化音频单元
    OSStatus result = AudioUnitInitialize(_audioUnit);
    NSLog(@"result %d", result);
}

static OSStatus PlayCallback(void *inRefCon,
                             AudioUnitRenderActionFlags *ioActionFlags,
                             const AudioTimeStamp *inTimeStamp,
                             UInt32 inBusNumber,
                             UInt32 inNumberFrames,
                             AudioBufferList *ioData) {
    SCPlayer *player = (__bridge SCPlayer *)inRefCon;
    
    // 从流中读取固定长度的数据，并导入到 ioData 的指定缓冲区中
    ioData->mBuffers[0].mDataByteSize =
    (UInt32)[player->_inputSteam read:ioData->mBuffers[0].mData
                            maxLength:(NSInteger)ioData->mBuffers[0].mDataByteSize];;
    NSLog(@"读入的数据大小(out size): %d", ioData->mBuffers[0].mDataByteSize);
    
    player->_buffList = ioData;

    // 读不出数据说明已经播放完毕
    if (ioData->mBuffers[0].mDataByteSize <= 0 ||
        !(player->_inputSteam.hasBytesAvailable)) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [player stop];
        });
    }
    return noErr;
}

- (void)dealloc {
    AudioOutputUnitStop(_audioUnit);
    AudioUnitUninitialize(_audioUnit);
    AudioComponentInstanceDispose(_audioUnit);
    
    if (_buffList != NULL) {
        free(_buffList);
        _buffList = NULL;
    }
}

#pragma mark - Tool
// 打印音频流基本信息
- (void)printAudioStreamBasicDescription:(AudioStreamBasicDescription)asbd {
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
    printf("\n");
}


@end
