//
//  mp3_encoder.h
//  Mp3Encoder
//
//  Created by SeacenLiu on 2019/5/6.
//  Copyright © 2019 SeacenLiu. All rights reserved.
//

#ifndef mp3_encoder_h
#define mp3_encoder_h

#include <stdio.h>
#include "lame.h"

class Mp3Encoder {
private:
    FILE* pcmFile;
    FILE* mp3File;
    lame_t lameClient;
    
public:
    Mp3Encoder();
    ~Mp3Encoder();
    /**
     初始化Mp3编码器

     @param pcmFilePath pcm文件路径
     @param mp3FilePath mp3文件路径
     @param sampleRate 采样率
     @param channels 声道数
     @param bitRate 比特率
     @return 0表示成功 -1表示失败
     */
    int Init(const char* pcmFilePath, const char* mp3FilePath, int sampleRate, int channels, int bitRate);
    void Encode();
    void Destory();
};

#endif /* mp3_encoder_h */
