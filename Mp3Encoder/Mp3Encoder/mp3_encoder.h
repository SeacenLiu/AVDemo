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
    int Init(const char* pcmFilePath, const char* mp3FilePath, int sampleRate, int channels, int bitRate);
    void Encode();
    void Destory();
};

#endif /* mp3_encoder_h */
