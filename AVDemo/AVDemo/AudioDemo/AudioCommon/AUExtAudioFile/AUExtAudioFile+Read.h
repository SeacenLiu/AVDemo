//
//  AUExtAudioFile+Read.h
//  AVDemo
//
//  Created by SeacenLiu on 2020/2/2.
//  Copyright © 2020 SeacenLiu. All rights reserved.
//

#import "AUExtAudioFile.h"

NS_ASSUME_NONNULL_BEGIN

@interface AUExtAudioFile (Read)

/** 用于读文件
 *  path: 要读取文件的路径
 *  clientabsd: 从文件中读取数据后的输出给app的音频数据格式，函数内部会使用实际的采样率和声道数，
 *              这里只需要指定采样格式和存储方式(planner还是packet)
 *  repeat:当到达文件的末尾后，是否重新开始读取
 */
- (instancetype)initWithReadPath:(NSString*)path
                            adsb:(AudioStreamBasicDescription)clientabsd
                       canrepeat:(BOOL)repeat;
- (OSStatus)readFrames:(UInt32*)framesNum
          toBufferData:(AudioBufferList*)bufferlist;

@end

NS_ASSUME_NONNULL_END
