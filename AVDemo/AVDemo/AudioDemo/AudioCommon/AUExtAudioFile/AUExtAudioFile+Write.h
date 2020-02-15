//
//  AUExtAudioFile+Write.h
//  AVDemo
//
//  Created by SeacenLiu on 2020/2/2.
//  Copyright © 2020 SeacenLiu. All rights reserved.
//

#import "AUExtAudioFile.h"

NS_ASSUME_NONNULL_BEGIN

@interface AUExtAudioFile (Write)

/** 用于写文件
 *  path: 要写入音频数据的文件路径
 *  clientabsd: 由APP端传输给Unit的音频数据格式(此时是PCM数据),
 *              然后Unit内部会经过编码再写入文件
 *  typeId: 指定封装格式(每一个封装格式对应特定的一种或几种编码方式)
 *  async: 是否异步写入数据，默认同步写入
 */
- (instancetype)initWithWritePath:(NSString*)path
                             adsb:(AudioStreamBasicDescription)clientabsd
                       fileTypeId:(AUAudioFileType)typeId;

- (OSStatus)writeFrames:(UInt32)framesNum
           toBufferData:(AudioBufferList*)bufferlist;

- (OSStatus)writeFrames:(UInt32)framesNum
           toBufferData:(AudioBufferList*)bufferlist
                  async:(BOOL)async;

@end

NS_ASSUME_NONNULL_END
