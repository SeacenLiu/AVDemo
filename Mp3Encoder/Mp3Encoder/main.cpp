//
//  main.cpp
//  Mp3Encoder
//
//  Created by SeacenLiu on 2019/5/6.
//  Copyright © 2019 SeacenLiu. All rights reserved.
//

#include <iostream>
#include "mp3_encoder.h"
using namespace std;

int main(int argc, const char * argv[]) {
    Mp3Encoder *encoder = new Mp3Encoder();
    // FIXME: - Edit Scheme -> Run -> Options -> Working Directory 设置工作路径
    const char* pcmFilePath = "./Resource/vocal.pcm";
    const char* mp3FilePath = "./Resource/output.mp3";
    int sampleRate = 44100;
    int channels = 2;
    int bitRate = 128 * 1024;
    if (encoder->Init(pcmFilePath, mp3FilePath, sampleRate, channels, bitRate) == 0) {
        encoder->Encode();
        cout << "Encode successed!" << endl;
    } else {
        cout << "Failed encoder init." << endl;
    }
    delete encoder;
    return 0;
}
