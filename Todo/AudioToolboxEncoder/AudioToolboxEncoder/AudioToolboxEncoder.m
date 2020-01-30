//
//  AudioToolboxEncoder.m
//  AudioToolboxEncoder
//
//  Created by SeacenLiu on 2019/12/16.
//  Copyright © 2019 SeacenLiu. All rights reserved.
//

#import "AudioToolboxEncoder.h"

@interface AudioToolboxEncoder()

@property (nonatomic) AudioConverterRef      audioConverter;

@property (nonatomic) uint8_t*               aacBuffer;
@property (nonatomic) UInt32                 aacBufferSize;
@property (nonatomic) uint8_t*               pcmBuffer;
@property (nonatomic) size_t                 pcmBufferSize;

@property (nonatomic) UInt32                 channels;
@property (nonatomic) NSInteger              inputSampleRate;

@property (nonatomic) BOOL                   isCompletion;
@property (nonatomic) BOOL                   withADTSHeader;

@property (nonatomic) int64_t                presentationTimeMills;

@property (readwrite, weak) id<AudioToolboxEncoderFillDataDelegate> fillAudioDataDelegate;

@end

@implementation AudioToolboxEncoder

- (instancetype)initWithSampleRate:(NSInteger)inputSampleRate
                          channels:(int)channels
                           bitRate:(int)bitRate
                    withADTSHeader:(BOOL)withADTSHeader
                 filleDataDelegate:(id<AudioToolboxEncoderFillDataDelegate>) fillAudioDataDelegate {
    if(self = [super init]) {
        // 初始化属性
        _audioConverter = NULL;
        _inputSampleRate = inputSampleRate;
        _pcmBuffer = NULL;
        _pcmBufferSize = 0;
        _presentationTimeMills = 0;
        _isCompletion = NO;
        _aacBuffer = NULL;
        _channels = channels;
        _withADTSHeader = withADTSHeader;
        _fillAudioDataDelegate = fillAudioDataDelegate;
        // 配置编码器
        [self setupEncoderWithSampleRate:inputSampleRate channels:channels bitRate:bitRate];
        // 在指定的编码线程中进行异步解码操作
        dispatch_queue_t encoderQueue = dispatch_queue_create("com.seacen.acc.encoder", DISPATCH_QUEUE_SERIAL);
        dispatch_async(encoderQueue, ^{
            [self encoder];
        });
    }
    return self;
}

#pragma mark - 配置编码器
- (void)setupEncoderWithSampleRate:(NSInteger)inputSampleRate
                          channels:(int)channels
                           bitRate:(UInt32)bitRate {
    // 构建输入流描述(InputABSD)
    AudioStreamBasicDescription inAudioStreamBasicDescription = {0};
    UInt32 bytesPerSample = sizeof (SInt16); // 样本字节数
    inAudioStreamBasicDescription.mFormatID = kAudioFormatLinearPCM; // PCM 样本格式
    inAudioStreamBasicDescription.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked; // SInt16 并且可组包
    inAudioStreamBasicDescription.mBytesPerPacket = bytesPerSample * channels; // 每个包的字节数
    inAudioStreamBasicDescription.mBytesPerFrame = bytesPerSample * channels; // 每一帧的字节数
    inAudioStreamBasicDescription.mChannelsPerFrame = channels; // 声道数
    inAudioStreamBasicDescription.mFramesPerPacket = 1; // 每一包的帧数
    inAudioStreamBasicDescription.mBitsPerChannel = 8 * channels; // 每一个声道的二进制数
    inAudioStreamBasicDescription.mSampleRate = inputSampleRate; // 输入的采样率
    inAudioStreamBasicDescription.mReserved = 0; // 保留字段
    // 构建输出流描述(OutputABSD)
    AudioStreamBasicDescription outAudioStreamBasicDescription = {0};
    outAudioStreamBasicDescription.mSampleRate = inAudioStreamBasicDescription.mSampleRate;
    outAudioStreamBasicDescription.mFormatID = kAudioFormatMPEG4AAC; // 设置编码格式
    outAudioStreamBasicDescription.mFormatFlags = kMPEG4Object_AAC_LC; // 无损编码 ，0表示没有
    outAudioStreamBasicDescription.mBytesPerPacket = 0;
    outAudioStreamBasicDescription.mFramesPerPacket = 1024; // ACC 编码要求的帧大小
    outAudioStreamBasicDescription.mBytesPerFrame = 0;
    outAudioStreamBasicDescription.mChannelsPerFrame = inAudioStreamBasicDescription.mChannelsPerFrame;
    outAudioStreamBasicDescription.mBitsPerChannel = 0;
    outAudioStreamBasicDescription.mReserved = 0;
    // 构建编码器类描述（软编带有硬件加速）
    AudioClassDescription *description = [self
                                          getAudioClassDescriptionWithType:kAudioFormatMPEG4AAC
                                          fromManufacturer:kAppleSoftwareAudioCodecManufacturer];
    // 构建 AudioConverter
    OSStatus status = AudioConverterNewSpecific(&inAudioStreamBasicDescription,
                                                &outAudioStreamBasicDescription,
                                                1, // 实例数量
                                                description,
                                                &_audioConverter);
    if (status != 0) {
        NSLog(@"setup converter: %d", (int)status);
    }
    // 设置 _audioConverter 的比特率
    UInt32 ulSize = sizeof(bitRate);
    status = AudioConverterSetProperty(_audioConverter,
                                       kAudioConverterEncodeBitRate,
                                       ulSize,
                                       &bitRate);
    // 设置 _audioConverter 最大输出包大小
    UInt32 size = sizeof(_aacBufferSize);
    AudioConverterGetProperty(_audioConverter,
                              kAudioConverterPropertyMaximumOutputPacketSize,
                              &size,
                              &_aacBufferSize);
    NSLog(@"Expected BitRate is %@, Output PacketSize is %d", @(bitRate), _aacBufferSize);
    // 置空 _aacBuffer
    _aacBuffer = malloc(_aacBufferSize * sizeof(uint8_t));
    memset(_aacBuffer, 0, _aacBufferSize);
}

// 根据根据类型和厂商建设
- (AudioClassDescription *)getAudioClassDescriptionWithType:(UInt32)type
                                           fromManufacturer:(UInt32)manufacturer {
    OSStatus st;
    static AudioClassDescription desc;
    // 获取 type 类型的 Encoders 属性大小
    UInt32 encoderSpecifier = type;
    UInt32 size;
    st = AudioFormatGetPropertyInfo(kAudioFormatProperty_Encoders,
                                    sizeof(encoderSpecifier),
                                    &encoderSpecifier,
                                    &size);
    if (st) {
        NSLog(@"error getting audio format propery info: %d", (int)(st));
        return nil;
    }
    // 查看这些编码器是否有符合厂商要求的
    unsigned int count = size / sizeof(AudioClassDescription);
    AudioClassDescription descriptions[count];
    st = AudioFormatGetProperty(kAudioFormatProperty_Encoders,
                                sizeof(encoderSpecifier),
                                &encoderSpecifier,
                                &size,
                                descriptions);
    if (st) {
        NSLog(@"error getting audio format propery: %d", (int)(st));
        return nil;
    }
    for (unsigned int i = 0; i < count; i++) {
        if ((type == descriptions[i].mSubType) &&
            (manufacturer == descriptions[i].mManufacturer)) {
            memcpy(&desc, &(descriptions[i]), sizeof(desc));
            return &desc;
        }
    }
    
    return nil;
}

#pragma mark - （*）编码方法
- (void)encoder {
    while (!_isCompletion) {
        NSData* outputData = nil;
        if (_audioConverter) {
            NSError *error = nil;
            // 初始化输出音频缓冲
            AudioBufferList outAudioBufferList = {0};
            outAudioBufferList.mNumberBuffers = 1;
            outAudioBufferList.mBuffers[0].mNumberChannels = _channels;
            outAudioBufferList.mBuffers[0].mDataByteSize = (int)_aacBufferSize;
            outAudioBufferList.mBuffers[0].mData = _aacBuffer;
            // 构建音频流包描述
            AudioStreamPacketDescription *outPacketDescription = NULL;
            UInt32 ioOutputDataPacketSize = 1;
            
            // 重要！！！
            // Converts data supplied by an input callback function, supporting non-interleaved and packetized formats.
            // Produces a buffer list of output data from an AudioConverter. The supplied input callback function is called whenever necessary.
            // 编码器设置数据输入回调(支持非交错和分组格式)
            // 通过 inInputDataProc 填充数据，系统会直接向 outAudioBufferList 导入输出音频数据
            OSStatus status = AudioConverterFillComplexBuffer(_audioConverter,
                                                              inInputDataProc,
                                                              (__bridge void *)(self),
                                                              &ioOutputDataPacketSize,
                                                              &outAudioBufferList,
                                                              outPacketDescription);
            if (status == 0) {
                NSData *rawAAC = [NSData dataWithBytes:outAudioBufferList.mBuffers[0].mData
                                                length:outAudioBufferList.mBuffers[0].mDataByteSize];
                if (_withADTSHeader) {
                    NSData *adtsHeader = [self adtsDataForPacketLength:rawAAC.length];
                    NSMutableData *fullData = [NSMutableData dataWithData:adtsHeader];
                    [fullData appendData:rawAAC];
                    outputData = fullData;
                } else {
                    outputData = rawAAC;
                }
            } else {
                error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
            }
            if (_fillAudioDataDelegate  && [_fillAudioDataDelegate respondsToSelector:@selector(outputAACPakcet:presentationTimeMills:error:)]) {
                [_fillAudioDataDelegate outputAACPakcet:outputData
                                  presentationTimeMills:_presentationTimeMills
                                                  error:error];
            }
        } else {
            NSLog(@"Audio Converter Init Failed...");
            break;
        }
    }
    if (_fillAudioDataDelegate && [_fillAudioDataDelegate respondsToSelector:@selector(onCompletion)]) {
        [_fillAudioDataDelegate onCompletion];
    }
}

/**
 *  A callback function that supplies audio data to convert. This callback is invoked repeatedly as the converter is ready for new input data.
 
 */
OSStatus inInputDataProc(AudioConverterRef inAudioConverter,
                         UInt32 *ioNumberDataPackets,
                         AudioBufferList *ioData,
                         AudioStreamPacketDescription **outDataPacketDescription,
                         void *inUserData) {
    AudioToolboxEncoder *encoder = (__bridge AudioToolboxEncoder *)(inUserData);
    return [encoder fillAudioRawData:ioData ioNumberDataPackets:ioNumberDataPackets];
}

#pragma mark - 填充音频原数据
- (OSStatus)fillAudioRawData:(AudioBufferList *)ioData
         ioNumberDataPackets:(UInt32 *)ioNumberDataPackets {
    UInt32 requestedPackets = *ioNumberDataPackets;
    uint32_t bufferLength = requestedPackets * _channels * 2;
    uint32_t bufferRead = 0;
    if(NULL == _pcmBuffer) {
        _pcmBuffer = malloc(bufferLength);
    }
    // 在代理中获取数据
    if(_fillAudioDataDelegate && [_fillAudioDataDelegate respondsToSelector:@selector(fillAudioData:bufferSize:)]) {
        bufferRead = [_fillAudioDataDelegate fillAudioData:_pcmBuffer bufferSize:bufferLength];
    }
    if (bufferRead <= 0) {
        *ioNumberDataPackets = 0;
        _isCompletion = YES;
        return -1;
    }
    _presentationTimeMills += (float)requestedPackets * 1000 / (float)_inputSampleRate;
    // 进行 ioData 的数据填充
    ioData->mBuffers[0].mData = _pcmBuffer;
    ioData->mBuffers[0].mDataByteSize = bufferRead;
    ioData->mNumberBuffers = 1;
    ioData->mBuffers[0].mNumberChannels = _channels;
    *ioNumberDataPackets = 1 ;
    return noErr;
}

/**
 *  Add ADTS header at the beginning of each and every AAC packet.
 *  This is needed as MediaCodec encoder generates a packet of raw
 *  AAC data.
 *
 *  Note the packetLen must count in the ADTS header itself.
 *  See: http://wiki.multimedia.cx/index.php?title=ADTS
 *  Also: http://wiki.multimedia.cx/index.php?title=MPEG-4_Audio#Channel_Configurations
 **/
- (NSData*)adtsDataForPacketLength:(NSUInteger)packetLength {
    int adtsLength = 7;
    char *packet = malloc(sizeof(char) * adtsLength);
    // Variables Recycled by addADTStoPacket
    int profile = 2;  //AAC LC
    //39=MediaCodecInfo.CodecProfileLevel.AACObjectELD;
    int freqIdx = 4;  //44.1KHz
    int chanCfg = _channels;  //MPEG-4 Audio Channel Configuration. 1 Channel front-center
    NSUInteger fullLength = adtsLength + packetLength;
    // fill in ADTS data
    packet[0] = (char)0xFF; // 11111111     = syncword
    packet[1] = (char)0xF9; // 1111 1 00 1  = syncword MPEG-2 Layer CRC
    packet[2] = (char)(((profile-1)<<6) + (freqIdx<<2) +(chanCfg>>2));
    packet[3] = (char)(((chanCfg&3)<<6) + (fullLength>>11));
    packet[4] = (char)((fullLength&0x7FF) >> 3);
    packet[5] = (char)(((fullLength&7)<<5) + 0x1F);
    packet[6] = (char)0xFC;
    NSData *data = [NSData dataWithBytesNoCopy:packet length:adtsLength freeWhenDone:YES];
    return data;
}

- (void)dealloc {
    if(_pcmBuffer) {
        free(_pcmBuffer);
        _pcmBuffer = NULL;
    }
    if(_aacBuffer) {
        free(_aacBuffer);
        _aacBuffer = NULL;
    }
    AudioConverterDispose(_audioConverter);
}

@end

